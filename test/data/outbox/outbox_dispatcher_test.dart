import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

/// Storage that is never available, the way a missing platform plugin behaves.
class _BrokenPrefs extends Prefs {
  _BrokenPrefs() : super.forTesting();

  @override
  Future<String?> getOutbox() async => throw MissingPluginException('no prefs plugin');

  @override
  Future<void> setOutbox(String json) async => throw MissingPluginException('no prefs plugin');
}

/// Storage whose writes can be held back by the test.
class _HoldWritePrefs extends Prefs {
  _HoldWritePrefs() : super.forTesting();

  Completer<void>? hold;

  @override
  Future<void> setOutbox(String json) async {
    final h = hold;
    if (h != null) await h.future;
    return super.setOutbox(json);
  }
}

/// Storage that reads fine but loses its first write.
class _FailFirstWritePrefs extends Prefs {
  _FailFirstWritePrefs() : super.forTesting();

  int writes = 0;

  @override
  Future<void> setOutbox(String json) async {
    writes++;
    if (writes == 1) throw MissingPluginException('no prefs plugin');
    return super.setOutbox(json);
  }
}

void main() {
  final t0 = DateTime.utc(2026, 8, 28, 11);
  late OutboxStore store;
  late List<String> sent;
  late List<Object> failures; // queued errors thrown by the fake sender, FIFO
  late List<_FakeTimer> timers;
  var settings = const OfflineQueueSettings();

  late DateTime Function() originalNow;
  late Timer Function(Duration, void Function()) originalTimerFactory;
  late double Function() originalJitter;
  late bool originalLifecycleObserverEnabled;
  late bool originalDisableNetwork;

  DioException dio(DioExceptionType type, {int? status}) {
    final options = RequestOptions(path: '/event');
    return DioException(
      requestOptions: options,
      type: type,
      response: status == null ? null : Response(requestOptions: options, statusCode: status),
    );
  }

  OutboxEntry entry(String id, {DateTime? createdAt}) =>
      OutboxEntry(id: id, kind: OutboxKind.event, createdAt: createdAt ?? t0, body: {'id': id});

  Future<void> sender(OutboxEntry e) async {
    if (failures.isNotEmpty) throw failures.removeAt(0);
    sent.add(e.id);
  }

  OutboxDispatcher dispatcher() => OutboxDispatcher(store: store, sender: sender, settings: () => settings);

  setUp(() {
    originalNow = Clock.now;
    originalTimerFactory = OutboxDispatcher.timerFactory;
    originalJitter = OutboxDispatcher.jitter;
    originalLifecycleObserverEnabled = OutboxDispatcher.lifecycleObserverEnabled;
    originalDisableNetwork = ErrorReporter.disableNetworkForTests;

    SharedPreferences.setMockInitialValues({});
    ErrorReporter.disableNetworkForTests = true;
    // Initialised but silent: the dispatcher logs through talker on every
    // step and the test output should stay readable.
    LoggerManager.instance.configure(LogLevel.none);
    // A fresh Prefs wrapper per test: `Prefs.instance` keeps the
    // `SharedPreferences` snapshot it read first, so the mock values set above
    // would not be visible through it.
    store = OutboxStore(prefs: Prefs.forTesting());
    sent = [];
    failures = [];
    timers = [];
    settings = const OfflineQueueSettings();
    Clock.now = () => t0;
    OutboxDispatcher.timerFactory = (delay, cb) {
      final t = _FakeTimer(delay, cb);
      timers.add(t);
      return t;
    };
    OutboxDispatcher.jitter = () => 0.5;
    OutboxDispatcher.lifecycleObserverEnabled = false;
  });

  tearDown(() {
    Clock.now = originalNow;
    OutboxDispatcher.timerFactory = originalTimerFactory;
    OutboxDispatcher.jitter = originalJitter;
    OutboxDispatcher.lifecycleObserverEnabled = originalLifecycleObserverEnabled;
    ErrorReporter.disableNetworkForTests = originalDisableNetwork;
  });

  test('start drains persisted entries in FIFO order', () async {
    await store.load();
    await store.append(entry('a'), maxEntries: 10);
    await store.append(entry('b'), maxEntries: 10);

    final d = dispatcher();
    await d.start();
    await d.flush();

    expect(sent, ['a', 'b']);
    expect(await d.pendingCount, 0);
  });

  test('transient failure stops the drain, keeps the entry, schedules backoff without counting attempts', () async {
    final d = dispatcher();
    await d.start();
    failures.add(dio(DioExceptionType.connectionError));

    await d.enqueue(entry('a'));
    await d.flush();

    expect(sent, isEmpty);
    expect(await d.pendingCount, 1);
    expect(store.head!.attempts, 0);
    expect(timers.single.delay, const Duration(seconds: 5));
    expect(d.backoffLevel, 1);

    timers.single.fire();
    await d.flush();
    expect(sent, ['a']);
    expect(d.backoffLevel, 0);
  });

  test('backoff grows per consecutive failure and resets on success', () async {
    final d = dispatcher();
    await d.start();
    failures.addAll([dio(DioExceptionType.connectionError), dio(DioExceptionType.connectionError)]);
    await d.enqueue(entry('a'));
    await d.flush();
    timers.last.fire();
    await d.flush();
    expect(timers.map((t) => t.delay), [const Duration(seconds: 5), const Duration(seconds: 15)]);
    timers.last.fire();
    await d.flush();
    expect(sent, ['a']);
    expect(d.backoffLevel, 0);
  });

  test('server failures count attempts and drop the entry after maxServerAttempts', () async {
    final d = dispatcher();
    await d.start();
    failures.addAll(
      List.generate(OutboxDispatcher.maxServerAttempts, (_) => dio(DioExceptionType.badResponse, status: 503)),
    );
    await d.enqueue(entry('a'));
    await d.enqueue(entry('b'));

    for (var i = 0; i < OutboxDispatcher.maxServerAttempts; i++) {
      await d.flush();
      if (timers.isNotEmpty && timers.last.isActive) timers.last.fire();
    }
    await d.flush();

    expect(sent, ['b'], reason: 'a is dropped after 5 server failures, b is delivered');
    expect(await d.pendingCount, 0);
  });

  test('permanent failure drops the entry immediately and continues', () async {
    final d = dispatcher();
    await d.start();
    failures.add(dio(DioExceptionType.badResponse, status: 422));
    await d.enqueue(entry('a'));
    await d.enqueue(entry('b'));
    await d.flush();
    expect(sent, ['b']);
    expect(await d.pendingCount, 0);
    expect(timers, isEmpty);
  });

  test('expired entries are dropped before sending', () async {
    final d = dispatcher();
    await d.start();
    await d.enqueue(entry('old', createdAt: t0.subtract(const Duration(days: 8))));
    await d.enqueue(entry('fresh'));
    await d.flush();
    expect(sent, ['fresh']);
    expect(await d.pendingCount, 0);
  });

  test('overflow drops the oldest entry', () async {
    settings = const OfflineQueueSettings(maxEntries: 2);
    final d = dispatcher();
    await d.start();
    failures.add(dio(DioExceptionType.connectionError));
    await d.enqueue(entry('a'));
    await d.flush();
    await d.enqueue(entry('b'));
    await d.enqueue(entry('c'));
    expect(store.snapshot().map((e) => e.id), ['b', 'c']);
  });

  test('disabled: nothing is queued and nothing is sent, but disk entries survive', () async {
    await store.load();
    await store.append(entry('persisted'), maxEntries: 10);
    settings = const OfflineQueueSettings(enabled: false);

    final d = dispatcher();
    await d.start();
    await d.enqueue(entry('new'));
    await d.flush();

    expect(sent, isEmpty);
    expect(store.snapshot().map((e) => e.id), ['persisted']);

    settings = const OfflineQueueSettings();
    await d.flush();
    expect(sent, ['persisted']);
  });

  test('onRequestSucceeded resets backoff and drains', () async {
    final d = dispatcher();
    await d.start();
    failures.add(dio(DioExceptionType.connectionError));
    await d.enqueue(entry('a'));
    await d.flush();
    expect(d.backoffLevel, 1);

    d.onRequestSucceeded();
    await d.flush();
    expect(sent, ['a']);
    expect(timers.single.isActive, isFalse, reason: 'pending backoff timer is cancelled');
  });

  test('resume drains, pause cancels the timer', () async {
    final d = dispatcher();
    await d.start();
    failures.add(dio(DioExceptionType.connectionError));
    await d.enqueue(entry('a'));
    await d.flush();
    expect(timers.single.isActive, isTrue);

    d.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(timers.single.isActive, isFalse);

    d.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await d.flush();
    expect(sent, ['a']);
  });

  test('poke during a drain does not start a second drain; entries added meanwhile are delivered', () async {
    final gate = Completer<void>();
    var inFlight = 0;
    var maxInFlight = 0;
    final d = OutboxDispatcher(
      store: store,
      sender: (e) async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        if (e.id == 'a') await gate.future;
        inFlight--;
        sent.add(e.id);
      },
      settings: () => settings,
    );
    await d.start();
    await d.enqueue(entry('a'));
    d.poke();
    d.poke();
    await d.enqueue(entry('b'));
    gate.complete();
    await d.flush();
    expect(maxInFlight, 1);
    expect(sent, ['a', 'b']);
  });

  test('sender throwing a non-Dio error is permanent', () async {
    final d = dispatcher();
    await d.start();
    failures.add(StateError('boom'));
    await d.enqueue(entry('a'));
    await d.flush();
    expect(await d.pendingCount, 0);
  });

  test('SocketException from the sender is transient', () async {
    final d = dispatcher();
    await d.start();
    failures.add(const SocketException('down'));
    await d.enqueue(entry('a'));
    await d.flush();
    expect(await d.pendingCount, 1);
    expect(timers, hasLength(1));
  });

  test('a write failing right after a delivery stops the drain without a retry', () async {
    // The queue is seeded on disk, so the first write of the test is the one
    // that removes the delivered entry.
    SharedPreferences.setMockInitialValues({
      'gravity_outbox': jsonEncode([entry('a').toJson()]),
    });
    final prefs = _FailFirstWritePrefs();
    store = OutboxStore(prefs: prefs);
    final d = dispatcher();

    await d.start();
    await d.flush();

    expect(sent, ['a'], reason: 'delivered exactly once in this drain');
    expect(prefs.writes, 1, reason: 'the failing write is the one right after the delivery');
    expect(timers, isEmpty, reason: 'a storage failure is not a delivery failure: no backoff');
    expect(d.isDraining, isFalse);
  });

  test('unavailable storage never throws to the caller', () async {
    store = OutboxStore(prefs: _BrokenPrefs());
    final d = dispatcher();

    await d.start();
    await d.enqueue(entry('a'));
    await d.flush();

    expect(await d.pendingCount, 0);
    expect(sent, isEmpty);
    expect(timers, isEmpty);
  });

  test('flush retries a send that was already on the wire when it was called', () async {
    // The caller flushes because it just saw the network come back. The send
    // in flight was begun before that, so waiting for it to fail is not the
    // attempt the caller asked for.
    final onTheWire = Completer<void>();
    final release = Completer<void>();
    final calls = <String>[];
    var failNext = true;

    final d = OutboxDispatcher(
      store: store,
      sender: (e) async {
        calls.add(e.id);
        if (!failNext) {
          sent.add(e.id);
          return;
        }
        failNext = false;
        onTheWire.complete();
        await release.future;
        throw dio(DioExceptionType.connectionError);
      },
      settings: () => settings,
    );

    await d.start();
    await d.enqueue(entry('a'));
    await onTheWire.future;

    final flushing = d.flush();
    release.complete();
    await flushing;

    expect(calls, ['a', 'a'], reason: 'the doomed attempt is awaited, then retried');
    expect(sent, ['a']);
    expect(await d.pendingCount, 0);
    expect(d.backoffLevel, 0);
    expect(timers.where((t) => t.isActive), isEmpty, reason: 'no backoff pause survives the flush');
  });

  group('recovery', () {
    /// Lets a drain started by a signal run to its end without flush(), which
    /// would pierce backoff pauses and hide what the signal alone did.
    Future<void> settle() async {
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a success elsewhere does not pierce the pause after a server error', () async {
      final d = dispatcher();
      await d.start();
      failures.add(dio(DioExceptionType.badResponse, status: 503));
      await d.enqueue(entry('a'));
      await settle();
      expect(store.head!.attempts, 1);
      expect(timers.single.isActive, isTrue);

      d.onRequestSucceeded();
      await settle();
      expect(store.head!.attempts, 1, reason: 'a foreign success is not a reason to retry a 5xx early');
      expect(timers.single.isActive, isTrue, reason: 'the pause keeps ticking');
      expect(sent, isEmpty);

      timers.single.fire();
      await settle();
      expect(sent, ['a']);
    });

    test('a success elsewhere still pierces the pause after a network error', () async {
      final d = dispatcher();
      await d.start();
      failures.add(dio(DioExceptionType.connectionError));
      await d.enqueue(entry('a'));
      await settle();
      expect(timers.single.isActive, isTrue);

      d.onRequestSucceeded();
      await settle();
      expect(sent, ['a']);
      expect(timers.single.isActive, isFalse);
    });

    test('a poke that lands while a drain is finishing is not lost', () async {
      late OutboxDispatcher d;
      var signalled = false;
      // The signal fires in the microtask gap between the drain scheduling
      // its backoff timer and the drain's completion handler running.
      OutboxDispatcher.timerFactory = (delay, cb) {
        final t = _FakeTimer(delay, cb);
        timers.add(t);
        if (!signalled) {
          signalled = true;
          scheduleMicrotask(d.onRequestSucceeded);
        }
        return t;
      };
      d = dispatcher();
      await d.start();
      failures.add(dio(DioExceptionType.connectionError));
      await d.enqueue(entry('a'));
      await settle();

      expect(sent, ['a'], reason: 'the signal cancelled the timer, so it must have started a drain');
      expect(timers.where((t) => t.isActive), isEmpty);
      expect(await d.pendingCount, 0);
    });

    test('an entry that expires while the drain is busy is dropped, not sent', () async {
      var now = t0;
      Clock.now = () => now;
      final d = OutboxDispatcher(
        store: store,
        sender: (e) async {
          // Delivering 'a' takes so long that 'b' outlives maxAge meanwhile.
          if (e.id == 'a') now = t0.add(const Duration(days: 8));
          sent.add(e.id);
        },
        settings: () => settings,
      );
      await store.load();
      await store.append(entry('a'), maxEntries: 10);
      await store.append(entry('b'), maxEntries: 10);

      await d.start();
      await settle();
      expect(sent, ['a']);
      expect(store.isEmpty, isTrue, reason: "'b' is dropped as expired");
    });

    test('enabling the queue after start drains what was persisted', () async {
      await store.load();
      await store.append(entry('persisted'), maxEntries: 10);
      settings = const OfflineQueueSettings(enabled: false);

      final d = dispatcher();
      await d.start();
      await settle();
      expect(sent, isEmpty);

      settings = const OfflineQueueSettings();
      d.onSettingsChanged();
      await settle();
      expect(sent, ['persisted']);
    });

    test('enqueue reports whether the entry reached storage', () async {
      store = OutboxStore(prefs: _BrokenPrefs());
      final d = dispatcher();
      await d.start();
      expect(await d.enqueue(entry('a')), isFalse);

      store = OutboxStore(prefs: Prefs.forTesting());
      final ok = dispatcher();
      await ok.start();
      expect(await ok.enqueue(entry('a')), isTrue);
    });

    test('a reserved entry is persisted but skipped by drains until released', () async {
      final d = dispatcher();
      await d.start();
      expect(await d.reserve(entry('a')), isTrue);
      await settle();
      expect(store.snapshot().map((e) => e.id), ['a']);
      expect(sent, isEmpty);

      await d.flush();
      expect(sent, isEmpty, reason: 'the online path owns it');

      await d.enqueue(entry('b'));
      await settle();
      expect(sent, ['b'], reason: 'a drain steps over the reserved head');

      d.release('a');
      await settle();
      expect(sent, ['b', 'a']);
      expect(store.isEmpty, isTrue);
    });

    test('complete and discard remove a reserved entry without sending it', () async {
      final d = dispatcher();
      await d.start();
      await d.reserve(entry('a'));
      await d.complete('a');
      expect(store.isEmpty, isTrue);

      await d.reserve(entry('b'));
      await d.discard('b');
      expect(store.isEmpty, isTrue);
      await settle();
      expect(sent, isEmpty);
    });

    test('reserve is refused while the queue is disabled', () async {
      settings = const OfflineQueueSettings(enabled: false);
      final d = dispatcher();
      await d.start();
      expect(await d.reserve(entry('a')), isFalse);
      expect(store.isEmpty, isTrue);
    });
  });

  group('clear', () {
    Future<void> settle() async {
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<List<dynamic>> disk() async =>
        jsonDecode((await SharedPreferences.getInstance()).getString('gravity_outbox')!) as List<dynamic>;

    test('removes every entry from disk and memory and cancels the backoff pause', () async {
      final d = dispatcher();
      await d.start();
      failures.add(dio(DioExceptionType.connectionError));
      await d.enqueue(entry('a'));
      await d.enqueue(entry('b'));
      await settle();
      expect(timers.single.isActive, isTrue);

      await d.clear();

      expect(store.isEmpty, isTrue);
      expect(await disk(), isEmpty);
      expect(await d.pendingCount, 0);
      expect(timers.single.isActive, isFalse, reason: 'nothing left to retry');
      expect(d.backoffLevel, 0);

      d.onRequestSucceeded();
      await d.flush();
      expect(sent, isEmpty);
    });

    test('an entry the online path holds is dropped too; its completion is a no-op', () async {
      final d = dispatcher();
      await d.start();
      await d.reserve(entry('a'));
      await d.clear();
      expect(await disk(), isEmpty);

      await d.complete('a');
      d.release('a');
      await settle();
      expect(sent, isEmpty);
      expect(await d.pendingCount, 0);
    });

    test('works while the queue is disabled', () async {
      await store.load();
      await store.append(entry('persisted'), maxEntries: 10);
      settings = const OfflineQueueSettings(enabled: false);
      final d = dispatcher();
      await d.start();

      await d.clear();
      expect(await disk(), isEmpty);

      settings = const OfflineQueueSettings();
      d.onSettingsChanged();
      await settle();
      expect(sent, isEmpty);
    });

    test('a storage failure is thrown to the caller, not swallowed', () async {
      store = OutboxStore(prefs: _BrokenPrefs());
      final d = dispatcher();
      await d.start();
      await expectLater(d.clear(), throwsA(isA<MissingPluginException>()));
    });

    test('an entry the online path holds stays its own while the clear write is pending', () async {
      final prefs = _HoldWritePrefs();
      store = OutboxStore(prefs: prefs);
      final d = dispatcher();
      await d.start();
      // The reservation's write is slow; the clear queues up behind it, so
      // for a while 'b' is in memory, reserved, and not yet cleared.
      prefs.hold = Completer<void>();
      final reserving = d.reserve(entry('b'));
      await settle();
      final clearing = d.clear();
      await settle();
      d.onRequestSucceeded(); // a drain woken up now must not send 'b'
      await settle();
      expect(sent, isEmpty, reason: 'the online path still owns it');

      prefs.hold!.complete();
      await Future.wait([reserving, clearing]);
      expect(store.isEmpty, isTrue);
      await d.complete('b');
      await settle();
      expect(sent, isEmpty);
    });

    test('a clear that lands while a 5xx attempt is being recorded leaves no pause behind', () async {
      final prefs = _HoldWritePrefs();
      store = OutboxStore(prefs: prefs);
      final d = dispatcher();
      await d.start();
      // The drain woken by this enqueue hits a 503 and records the attempt;
      // the hold is armed after the enqueue's own write, so it catches the
      // drain's `replace` write and nothing else.
      failures.add(dio(DioExceptionType.badResponse, status: 503));
      await d.enqueue(entry('a'));
      prefs.hold = Completer<void>();
      await settle();
      expect(d.isDraining, isTrue, reason: 'the drain is stuck recording the attempt');
      expect(timers.where((t) => t.isActive), isEmpty, reason: 'no pause scheduled yet');

      final clearing = d.clear();
      await settle();
      prefs.hold!.complete();
      await clearing;
      await settle();

      expect(d.isDraining, isFalse);
      expect(timers.where((t) => t.isActive), isEmpty, reason: 'no server pause for a queue that is gone');
      expect(d.backoffLevel, 0);
      expect(store.isEmpty, isTrue);
      expect(sent, isEmpty);
    });

    test('a drain failing after the clear neither re-queues nor inherits a pause', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final d = OutboxDispatcher(
        store: store,
        sender: (e) async {
          calls++;
          if (calls == 1) {
            entered.complete();
            await release.future;
            throw dio(DioExceptionType.connectionError);
          }
          sent.add(e.id);
        },
        settings: () => settings,
      );
      await d.start();
      await d.enqueue(entry('a'));
      await entered.future;

      await d.clear();
      release.complete();
      await settle();

      expect(timers.where((t) => t.isActive), isEmpty, reason: 'nothing left to retry');
      expect(d.backoffLevel, 0);
      expect(store.isEmpty, isTrue);

      await d.enqueue(entry('b'));
      await settle();
      expect(sent, ['b'], reason: 'a new event does not wait out a pause that belonged to a cleared queue');
    });
  });
}
