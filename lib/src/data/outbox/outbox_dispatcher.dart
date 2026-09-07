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

/// Drains the outbox strictly FIFO, one entry at a time, and decides when to
/// try again. Wake-up signals: app start, return to foreground, any
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
  }) : _store = store,
       _sender = sender,
       _settings = settings;

  /// Server-side failures (408/429/5xx) tolerated per entry before it is dropped.
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
  Future<bool> enqueue(OutboxEntry entry) async {
    if (!await _persist(entry, 'enqueue')) return false;
    _log('queued ${entry.kind.name} ${entry.id}, pending ${_store.length}');
    poke();
    return true;
  }

  /// Persists [entry] on behalf of the online path that is about to send it.
  /// Drains skip it until [release], [complete] or [discard]. Returns whether
  /// the entry reached storage.
  Future<bool> reserve(OutboxEntry entry) async {
    _inFlight.add(entry.id);
    if (await _persist(entry, 'reserve')) return true;
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

  Future<bool> _persist(OutboxEntry entry, String section) async {
    final settings = _settings();
    if (!settings.enabled) return false;
    try {
      final dropped = await _store.append(entry, maxEntries: settings.maxEntries);
      for (final e in dropped) {
        _reportDropped(e, 'overflow');
      }
      return true;
    } catch (error, stackTrace) {
      _reportStoreError(section, error, stackTrace);
      return false;
    }
  }

  /// Starts a drain unless the queue is disabled, a backoff pause is still
  /// ticking, or there is nothing to send. A drain already running picks the
  /// request up when it finishes.
  void poke() {
    if (!_settings().enabled) return;
    if (_draining != null) {
      _pokeRequested = true;
      return;
    }
    if (_timer != null) return;
    if (_nextEntry() == null) return;
    _draining = _drain().whenComplete(() {
      _draining = null;
      if (_pokeRequested) {
        _pokeRequested = false;
        poke();
      }
    });
  }

  /// A request elsewhere just succeeded: the network is back. Pierces a pause
  /// caused by a network failure; a pause after a server error keeps ticking.
  void onRequestSucceeded() {
    if (_timer != null && _pausedAfter == RetryClass.server) return;
    _resetBackoff();
    poke();
  }

  /// The queue was switched on (or its limits changed): look at the disk now.
  void onSettingsChanged() {
    _resetBackoff();
    poke();
  }

  /// Drains now, ignoring a pending backoff pause, and completes when the drain
  /// stops (queue empty or blocked by a failure). Guarantees one send attempt
  /// begun after the call: a drain already in flight is awaited first, and a
  /// fresh attempt follows it unless that drain sent something after the call
  /// anyway. Never throws.
  Future<void> flush() async {
    // Documented as a no-op while disabled: do not even wait for a send that
    // was begun before the queue was switched off.
    if (!_settings().enabled) return;

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

  /// Oldest entry not owned by the online path.
  OutboxEntry? _nextEntry() {
    for (final entry in _store.snapshot()) {
      if (!_inFlight.contains(entry.id)) return entry;
    }
    return null;
  }

  Future<void> _drain() async {
    _cancelTimer();
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
        if (!_settings().enabled) return;
        final entry = _nextEntry();
        if (entry == null) return;

        // A slow delivery ahead of it may have aged this entry past maxAge.
        if (Clock.now().difference(entry.createdAt) > _settings().maxAge) {
          _reportDropped(entry, 'expired');
          await _store.removeById(entry.id);
          continue;
        }

        // Only the send is classified; every drop is reported before the store
        // is touched, so a failing write cannot swallow the report.
        _sendAttempts++;
        final epoch = _epoch;
        try {
          await _sender(entry);
        } catch (error, stackTrace) {
          // The queue was cleared while this was on the wire: nothing to
          // retry, and no pause for whatever gets queued next.
          if (epoch != _epoch) return;
          switch (classifyError(error)) {
            case RetryClass.transient:
              _scheduleRetry(RetryClass.transient);
              return;
            case RetryClass.server:
              final updated = entry.copyWith(attempts: entry.attempts + 1);
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
        _backoffLevel = 0;
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
        _resetBackoff();
        poke();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cancelTimer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _reportDropped(OutboxEntry entry, String reason, [Object? error, StackTrace? stackTrace]) {
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
