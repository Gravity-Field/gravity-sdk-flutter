import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:gravity_sdk/src/data/api/retry_class.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/backoff.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/models/external/offline_queue_settings.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/logger.dart';

typedef OutboxSender = Future<void> Function(OutboxEntry entry);

/// Drains ordinary entries FIFO. Modal retries have their own persisted retry
/// times in the same store, so a failed WRIMP cannot block later entries. Wake-up signals: app start, return to foreground, any
/// successful online request, a backoff timer, the queue being switched on,
/// and an explicit flush.
///
/// The online path persists an entry *before* sending it ([reserve]) and
/// removes it on success ([complete]); while it is reserved the drain steps
/// over it. After a crash nothing is reserved, so the entry is simply queued.
///
/// Nothing here throws to the caller: the queue is best effort, so a storage
/// failure is reported and swallowed. The one exception is [clear], whose
/// caller must learn when the data is still on disk.
class OutboxDispatcher with WidgetsBindingObserver {
  OutboxDispatcher({
    required OutboxStore store,
    required OutboxSender sender,
    required OfflineQueueSettings Function() settings,
    void Function(OutboxEntry entry)? onDropped,
  }) : _store = store,
       _sender = sender,
       _settings = settings,
       _onDropped = onDropped;

  /// Server-side failures tolerated for optional events. Modal WRIMP retries
  /// until queue expiry, so an outage cannot discard its frequency-cap event.
  static const int maxServerAttempts = 5;

  @visibleForTesting
  static Timer Function(Duration delay, void Function() callback) timerFactory = (delay, callback) =>
      Timer(delay, callback);

  @visibleForTesting
  static double Function() jitter = () => Random().nextDouble();

  /// Tests without a widgets binding switch the lifecycle observer off.
  @visibleForTesting
  static bool lifecycleObserverEnabled = true;

  final OutboxStore _store;
  final OutboxSender _sender;
  final OfflineQueueSettings Function() _settings;

  final void Function(OutboxEntry entry)? _onDropped;
  Timer? _modalTimer;
  final Set<String> _modalRetryOverrides = {};
  Timer? _timer;
  int _backoffLevel = 0;
  Future<void>? _draining;
  bool _started = false;

  /// A poke that arrived while a drain was finishing; honoured right after.
  bool _pokeRequested = false;

  /// Why the current backoff pause was scheduled. A success elsewhere means
  /// "the network is back", which only matters after a network failure: a
  /// server that just answered 5xx is not helped by an early retry.
  RetryClass? _pausedAfter;

  List<OutboxEntry> get snapshot => _store.snapshot();

  /// Presentation remains available when storage cannot be read. In-memory
  /// reservations still protect concurrent requests until storage recovers.
  Future<bool> load() async {
    try {
      await _store.load();
      return true;
    } catch (error, stackTrace) {
      _reportStoreError('load', error, stackTrace);
      return false;
    }
  }

  bool get _canDrain => _settings().enabled || _store.snapshot().any((e) => e.isModalImpression);

  /// Entries the online path is sending right now; drains step over them.
  final Set<String> _inFlight = {};

  /// Bumped by [clear]. Work that began under an older epoch (a send on the
  /// wire, an event waiting for its session) belongs to a queue that no
  /// longer exists and must neither re-queue itself nor leave a pause behind.
  int _epoch = 0;

  int get epoch => _epoch;

  /// Send attempts begun so far. [flush] compares it around the drain it waits
  /// for, to tell an attempt that started after the call from one that was
  /// already on the wire.
  int _sendAttempts = 0;

  @visibleForTesting
  int get backoffLevel => _backoffLevel;

  @visibleForTesting
  bool get isDraining => _draining != null;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await _store.load();
    } catch (error, stackTrace) {
      _reportStoreError('start', error, stackTrace);
    }
    _registerLifecycleObserver();
    poke();
  }

  /// Persists [entry] for later delivery and wakes the drain. Returns whether
  /// the entry reached storage; a `false` means the event is not protected.
  /// [precondition] is asked inside the write itself, so a queue cleared while
  /// this one waited its turn cannot be brought back to life by it.
  Future<bool> enqueue(OutboxEntry entry, {bool Function()? precondition}) async {
    if (!await _persist(entry, 'enqueue', precondition: precondition)) return false;
    _log('queued ${entry.kind.name} ${entry.id}, pending ${_store.length}');
    poke();
    return true;
  }

  /// The first modal attempt uses the existing reserve/complete online path,
  /// independent of an older request's backoff. On failed persistence it still
  /// makes one best-effort send, with the same immutable URL/user context.
  Future<bool> deliverModal(
    OutboxEntry entry, {
    bool Function()? precondition,
    void Function()? onEnqueued,
  }) async {
    assert(entry.isModalImpression);
    final epoch = _epoch;
    final persisted = await reserve(entry, precondition: precondition);
    // Appearance is independent of HTTP latency, rejection or retry. Notify
    // after the durable write (or its best-effort failure), before sending.
    try {
      onEnqueued?.call();
    } catch (error, stackTrace) {
      _reportStoreError('modalCallback', error, stackTrace);
    }
    if (_epoch != epoch || (precondition != null && !precondition())) {
      _inFlight.remove(entry.id);
      return false;
    }
    try {
      await _sender(entry);
      if (_epoch == epoch && persisted) await complete(entry.id);
      return true;
    } catch (error, stackTrace) {
      if (_epoch != epoch) {
        _inFlight.remove(entry.id);
        return persisted;
      }
      if (persisted) {
        try {
          await _deferModal(entry, error, stackTrace);
        } catch (storeError, storeTrace) {
          _reportStoreError('modalRetry', storeError, storeTrace);
        }
      } else if (classifyError(error) == RetryClass.permanent) {
        _reportDropped(entry, 'rejected', error, stackTrace);
      } else {
        _reportStoreError('modalBestEffort', error, stackTrace);
      }
      return persisted;
    } finally {
      _inFlight.remove(entry.id);
      poke();
    }
  }

  Future<void> _deferModal(OutboxEntry entry, Object error, StackTrace stackTrace) async {
    if (_storedEntry(entry.id) == null) return;
    final expired = entry.isExpired(_settings().maxAge, Clock.now());
    if (classifyError(error) == RetryClass.permanent || expired) {
      _reportDropped(
        entry,
        expired ? 'expired' : 'rejected',
        error,
        stackTrace,
      );
      await _store.removeById(entry.id);
      return;
    }
    final current = _storedEntry(entry.id)!;
    final delay = Backoff.delayFor(current.attempts, random: jitter());
    await _store.replace(
      current.copyWith(
        attempts: current.attempts + 1,
        body: {
          ...?current.body,
          'retryAt': Clock.now().add(delay).toUtc().toIso8601String(),
          'retryOnNetworkRestore': classifyError(error) == RetryClass.transient,
        },
      ),
    );
  }

  /// Persists [entry] on behalf of the online path that is about to send it.
  /// Drains skip it until [release], [complete] or [discard]. Returns whether
  /// the entry reached storage. [precondition] works as for [enqueue].
  Future<bool> reserve(OutboxEntry entry, {bool Function()? precondition}) async {
    _inFlight.add(entry.id);
    if (await _persist(entry, 'reserve', precondition: precondition)) return true;
    _inFlight.remove(entry.id);
    return false;
  }

  /// The online send of a reserved entry failed for a retryable reason: hand
  /// it to the drain.
  void release(String id) {
    if (!_inFlight.remove(id)) return;
    _log('released $id to the queue, pending ${_store.length}');
    poke();
  }

  /// Rewrites a reserved entry (the online path learned its identity after
  /// reserving it). A no-op when the entry was evicted meanwhile.
  Future<void> update(OutboxEntry entry) async {
    try {
      await _store.replace(entry);
    } catch (error, stackTrace) {
      _reportStoreError('update', error, stackTrace);
    }
  }

  /// The online send of a reserved entry succeeded.
  Future<void> complete(String id) => _forget(id, 'complete');

  /// The online send of a reserved entry failed permanently.
  Future<void> discard(String id) => _forget(id, 'discard');

  Future<void> _forget(String id, String section) async {
    _inFlight.remove(id);
    try {
      await _store.removeById(id);
    } catch (error, stackTrace) {
      _reportStoreError(section, error, stackTrace);
    }
  }

  Future<bool> _persist(OutboxEntry entry, String section, {bool Function()? precondition}) async {
    final settings = _settings();
    if (!settings.enabled && !entry.isModalImpression) return false;
    try {
      final dropped = precondition == null
          ? await _store.append(entry, maxEntries: settings.maxEntries)
          : await _store.appendIfStillWanted(
              entry,
              maxEntries: settings.maxEntries,
              stillWanted: precondition,
            );
      if (dropped == null) return false;
      for (final e in dropped) {
        _reportDropped(e, 'overflow');
      }
      return !dropped.any((e) => e.id == entry.id);
    } catch (error, stackTrace) {
      _reportStoreError(section, error, stackTrace);
      return false;
    }
  }

  /// Starts a drain unless the queue is disabled, a backoff pause is still
  /// ticking, or there is nothing to send. A drain already running picks the
  /// request up when it finishes.
  void poke() {
    if (!_canDrain) return;
    if (_draining != null) {
      _pokeRequested = true;
      return;
    }
    if (_nextEntry() == null) {
      _armModalTimer();
      return;
    }
    _draining = _drain().whenComplete(() {
      _draining = null;
      _armModalTimer();
      if (_pokeRequested) {
        _pokeRequested = false;
        poke();
      }
    });
  }

  /// A request elsewhere just succeeded: the network is back. Pierces a pause
  /// caused by a network failure; a pause after a server error keeps ticking.
  void onRequestSucceeded() {
    _modalRetryOverrides.addAll(
      _store
          .snapshot()
          .where((entry) => entry.isModalImpression && entry.modalRetryOnNetworkRestore)
          .map((entry) => entry.id),
    );
    if (_timer == null || _pausedAfter != RetryClass.server) _resetBackoff();
    poke();
  }

  /// The queue was switched on (or its limits changed): look at the disk now.
  void onSettingsChanged() {
    _wakeModalRetries();
    _resetBackoff();
    poke();
  }

  /// Drains now, ignoring a pending backoff pause, and completes when the drain
  /// stops (queue empty or blocked by a failure). Guarantees one send attempt
  /// begun after the call: a drain already in flight is awaited first, and a
  /// fresh attempt follows it unless that drain sent something after the call
  /// anyway. Never throws.
  Future<void> flush() async {
    // Optional buffering may be disabled while mandatory WRIMP still drains.
    // With no mandatory entries, preserve the disabled queue's no-op behavior.
    if (!_canDrain) return;

    // A send already on the wire was begun before the caller learned the
    // network is back, so waiting for it is not the attempt this flush asks
    // for. Awaiting it first also keeps its backoff timer from landing after
    // the reset below and blocking the fresh attempt.
    final attemptsBefore = _sendAttempts;
    await (_draining ?? Future<void>.value());
    if (_sendAttempts > attemptsBefore) return;

    _resetBackoff();
    try {
      await _store.load();
      _wakeModalRetries();
      // A removal whose write failed earlier is retried now that the caller
      // says storage or network is back; otherwise a delivered entry would
      // return from disk on the next launch.
      await _store.sync();
      poke();
    } catch (error, stackTrace) {
      _reportStoreError('flush', error, stackTrace);
    }
    await (_draining ?? Future<void>.value());
  }

  /// Drops every queued entry, including one the online path is sending
  /// right now (its completion then finds nothing to remove) and one a
  /// drain has on the wire (it is not re-queued on failure). Cancels the
  /// backoff pause: there is nothing left to retry. Works while the queue is
  /// disabled.
  ///
  /// Throws when storage refused the write: the caller asked for the data to
  /// be gone and must not be told it is when the disk still has it.
  /// Reserved ids are left alone: their owners drop them on completion, and
  /// keeping them reserved is what stops a drain from sending an entry the
  /// online path still owns while the clear waits behind an earlier write.
  Future<void> clear() async {
    _epoch++;
    _modalRetryOverrides.clear();
    _modalTimer?.cancel();
    _modalTimer = null;
    _resetBackoff();
    try {
      await _store.clear();
      _log('cleared, pending ${_store.length}');
    } catch (error, stackTrace) {
      _reportStoreError('clear', error, stackTrace);
      rethrow;
    }
  }

  /// Entries on disk, including those the online path is sending right now.
  Future<int> get pendingCount async {
    try {
      await _store.load();
      return _store.length;
    } catch (error, stackTrace) {
      _reportStoreError('pendingCount', error, stackTrace);
      return 0;
    }
  }

  /// The queued entry with [id] as it stands now, or null once it is gone.
  OutboxEntry? _storedEntry(String id) {
    for (final entry in _store.snapshot()) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Oldest eligible entry not owned by the online path; skip deferred WRIMP.
  OutboxEntry? _nextEntry() {
    final now = Clock.now();
    for (final entry in _store.snapshot()) {
      if (_inFlight.contains(entry.id)) continue;
      if (entry.isModalImpression) {
        if (entry.isExpired(_settings().maxAge, now) ||
            _modalRetryOverrides.contains(entry.id) ||
            entry.modalRetryAt == null ||
            !entry.modalRetryAt!.isAfter(now)) {
          return entry;
        }
      } else if (_settings().enabled && _timer == null) {
        return entry;
      }
    }
    return null;
  }

  void _wakeModalRetries() =>
      _modalRetryOverrides.addAll(_store.snapshot().where((entry) => entry.isModalImpression).map((entry) => entry.id));

  /// A single timer wakes eligible WRIMP retries in this same dispatcher.
  /// Retry timestamps are persisted, so restart does not reset server backoff.
  void _armModalTimer() {
    _modalTimer?.cancel();
    _modalTimer = null;
    DateTime? earliest;
    final now = Clock.now();
    for (final entry in _store.snapshot()) {
      if (!entry.isModalImpression || _inFlight.contains(entry.id)) continue;
      var retry = entry.modalRetryAt;
      if (retry == null) continue;
      final expiry = entry.createdAt.add(entry.effectiveMaxAge(_settings().maxAge));
      if (expiry.isBefore(retry)) retry = expiry;
      if (!retry.isAfter(now)) continue;
      if (earliest == null || retry.isBefore(earliest)) earliest = retry;
    }
    if (earliest != null) {
      _modalTimer = timerFactory(earliest.difference(now), () {
        _modalTimer = null;
        poke();
      });
    }
  }

  Future<void> _drain() async {
    // Names the storage step a failure came from: a write that fails right
    // after a delivery may leave the entry queued and send it twice, which is
    // a very different problem from a queue that cannot be read at all.
    var phase = 'prune';
    try {
      await _store.sync();
      final expired = await _store.pruneExpired(maxAge: _settings().maxAge, now: Clock.now());
      for (final e in expired) {
        _reportDropped(e, 'expired');
      }
      // A limit lowered after the queue was loaded applies to it as well.
      final overflow = await _store.pruneOverflow(maxEntries: _settings().maxEntries);
      for (final e in overflow) {
        _reportDropped(e, 'overflow');
      }

      while (true) {
        phase = 'queue';
        if (!_canDrain) return;
        final entry = _nextEntry();
        if (entry == null) return;

        // A slow delivery ahead of it may have aged this entry past maxAge.
        if (entry.isExpired(_settings().maxAge, Clock.now())) {
          _reportDropped(entry, 'expired');
          await _store.removeById(entry.id);
          continue;
        }

        // Only the send is classified; every drop is reported before the store
        // is touched, so a failing write cannot swallow the report.
        _modalRetryOverrides.remove(entry.id);
        _sendAttempts++;
        final epoch = _epoch;
        try {
          await _sender(entry);
        } catch (error, stackTrace) {
          // The queue was cleared while this was on the wire: nothing to
          // retry, and no pause for whatever gets queued next.
          if (epoch != _epoch) return;
          if (entry.isModalImpression) {
            await _deferModal(entry, error, stackTrace);
            continue;
          }
          switch (classifyError(error)) {
            case RetryClass.transient:
              _scheduleRetry(RetryClass.transient);
              return;
            case RetryClass.server:
              // The sender may have written the identity it resolved onto the
              // stored entry; count the attempt on that version, or the body
              // just frozen would be replaced by the stale snapshot.
              final current = _storedEntry(entry.id) ?? entry;
              final updated = current.copyWith(attempts: current.attempts + 1);
              if (updated.attempts >= maxServerAttempts) {
                _reportDropped(updated, 'rejected', error, stackTrace);
                await _store.removeById(entry.id);
                continue;
              }
              await _store.replace(updated);
              if (epoch != _epoch) return;
              _scheduleRetry(RetryClass.server);
              return;
            case RetryClass.permanent:
              _reportDropped(entry, 'rejected', error, stackTrace);
              await _store.removeById(entry.id);
              continue;
          }
        }

        phase = 'after_delivery';
        if (epoch != _epoch) return;
        await _store.removeById(entry.id);
        if (!entry.isModalImpression) _backoffLevel = 0;
        _log('delivered ${entry.kind.name} ${entry.id}, pending ${_store.length}');
      }
    } catch (error, stackTrace) {
      // Storage is unavailable: stop this drain instead of spinning on it.
      _reportStoreError('drain', error, stackTrace, extra: {'phase': phase});
    }
  }

  void _scheduleRetry(RetryClass cause) {
    _cancelTimer();
    final delay = Backoff.delayFor(_backoffLevel, random: jitter());
    _backoffLevel++;
    _pausedAfter = cause;
    _log('retry in ${delay.inSeconds}s (level $_backoffLevel, after ${cause.name})');
    _timer = timerFactory(delay, () {
      _timer = null;
      poke();
    });
  }

  void _resetBackoff() {
    _backoffLevel = 0;
    _cancelTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _registerLifecycleObserver() {
    if (!lifecycleObserverEnabled) return;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // No widgets binding (pure Dart context): rely on the other signals.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _wakeModalRetries();
        _resetBackoff();
        poke();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cancelTimer();
        _modalTimer?.cancel();
        _modalTimer = null;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _reportDropped(OutboxEntry entry, String reason, [Object? error, StackTrace? stackTrace]) {
    _onDropped?.call(entry);
    _modalRetryOverrides.remove(entry.id);
    _log('dropped ${entry.kind.name} ${entry.id}: $reason');
    ErrorReporter.instance.report(
      message: 'Outbox entry dropped: $reason${error == null ? '' : ' ($error)'}',
      level: 'warning',
      section: 'OutboxDispatcher',
      stacktrace: stackTrace?.toString(),
      extra: {
        'kind': entry.kind.name,
        'attempts': entry.attempts,
        'ageSeconds': Clock.now().difference(entry.createdAt).inSeconds,
      },
      tags: {'category': 'delivery', 'outcome': reason},
    );
  }

  void _reportStoreError(String section, Object error, StackTrace stackTrace, {Map<String, dynamic>? extra}) {
    _log('store unavailable in $section${extra == null ? '' : ' $extra'}: $error');
    ErrorReporter.instance.report(
      message: 'Outbox store unavailable: $error',
      level: 'warning',
      section: 'OutboxDispatcher.$section',
      stacktrace: stackTrace.toString(),
      extra: extra,
      tags: const {'category': 'delivery', 'outcome': 'store_error'},
    );
  }

  void _log(String message) {
    if (LoggerManager.instance.isInitialized) talker.debug('[outbox] $message');
  }
}
