import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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

class _ManualTimer implements Timer {
  _ManualTimer(this.delay, this.callback);
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

// Independent durable state: never confuses SharedPreferences' optimistic
// cache with an acknowledged platform write.
class _Disk extends Prefs {
  _Disk() : super.forTesting();
  String? durable;
  int rejectWrites = 0;
  int writes = 0;
  @override
  Future<String?> getOutbox() async => durable;
  @override
  Future<void> setOutbox(String json) async {
    writes++;
    if (rejectWrites > 0) {
      rejectWrites--;
      throw StateError('injected disk failure');
    }
    durable = json;
  }
}

Future<void> _until(bool Function() predicate) async {
  final watch = Stopwatch()..start();
  while (!predicate()) {
    if (watch.elapsed > const Duration(seconds: 3)) {
      fail('observable dispatcher state did not arrive');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  final epoch = DateTime.utc(2026, 9, 7, 10, 0, 0, 123);
  final oldClock = Clock.now;
  final oldTimer = OutboxDispatcher.timerFactory;
  final oldJitter = OutboxDispatcher.jitter;
  final oldLifecycle = OutboxDispatcher.lifecycleObserverEnabled;
  final oldReporting = ErrorReporter.disableNetworkForTests;
  late _Disk disk;
  late OutboxStore store;
  late OfflineQueueSettings settings;
  late List<_ManualTimer> timers;
  late List<String> sent;
  late DateTime now;
  final dispatchers = <OutboxDispatcher>[];

  OutboxEntry entry(String id) => OutboxEntry(
    id: id,
    kind: OutboxKind.event,
    createdAt: epoch,
    body: {'id': id},
  );
  OutboxDispatcher make({OutboxSender? sender}) {
    final d = OutboxDispatcher(
      store: store,
      settings: () => settings,
      sender:
          sender ??
          (e) async {
            sent.add(e.id);
          },
    );
    dispatchers.add(d);
    return d;
  }

  Future<void> idle(OutboxDispatcher d) => _until(() => !d.isDraining);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LoggerManager.instance.configure(LogLevel.none);
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    OutboxDispatcher.jitter = () => 0.5;
    timers = [];
    OutboxDispatcher.timerFactory = (delay, cb) {
      final t = _ManualTimer(delay, cb);
      timers.add(t);
      return t;
    };
    disk = _Disk();
    store = OutboxStore(prefs: disk);
    settings = const OfflineQueueSettings();
    sent = [];
    now = epoch;
    Clock.now = () => now;
  });
  tearDown(() {
    for (final d in dispatchers) {
      d.didChangeAppLifecycleState(AppLifecycleState.detached);
    }
    dispatchers.clear();
    Clock.now = oldClock;
    OutboxDispatcher.timerFactory = oldTimer;
    OutboxDispatcher.jitter = oldJitter;
    OutboxDispatcher.lifecycleObserverEnabled = oldLifecycle;
    ErrorReporter.disableNetworkForTests = oldReporting;
  });

  test(
    'reserve release with simultaneous flush timer and success sends once',
    () async {
      var attempts = 0;
      var active = 0;
      var peak = 0;
      final entered = Completer<void>();
      final finish = Completer<void>();
      final d = make(
        sender: (e) async {
          attempts++;
          if (attempts == 1) throw const SocketException('offline');
          active++;
          if (active > peak) peak = active;
          entered.complete();
          await finish.future;
          active--;
          sent.add(e.id);
        },
      );
      await d.start();
      expect(await d.reserve(entry('a')), isTrue);
      await d.flush();
      expect(attempts, 0, reason: 'online owner has exclusive access');
      d.release('a');
      d.release('a');
      await idle(d);
      expect(attempts, 1);
      timers.single.fire();
      final flushes = List.generate(8, (_) => d.flush());
      d.onRequestSucceeded();
      await entered.future.timeout(const Duration(seconds: 3));
      finish.complete();
      await Future.wait(flushes);
      await idle(d);
      expect(attempts, 2);
      expect(peak, 1);
      expect(sent, ['a']);
      expect(await d.pendingCount, 0);
    },
  );

  test(
    '503 outage recovers on timer alone despite foreign successes',
    () async {
      var attempts = 0;
      final d = make(
        sender: (e) async {
          if (++attempts == 1) {
            final req = RequestOptions(path: '/event');
            throw DioException(
              requestOptions: req,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: req, statusCode: 503),
            );
          }
          sent.add(e.id);
        },
      );
      await d.start();
      await d.enqueue(entry('a'));
      await idle(d);
      expect(store.head!.attempts, 1);
      for (var i = 0; i < 10; i++) {
        d.onRequestSucceeded();
      }
      expect(attempts, 1);
      expect(timers.single.isActive, isTrue);
      timers.single.fire();
      await idle(d);
      expect(sent, ['a']);
      expect(await d.pendingCount, 0);
    },
  );

  test(
    'failed complete is retried by flush without resending delivered event',
    () async {
      final d = make();
      await d.start();
      await d.reserve(entry('a'));
      disk.rejectWrites = 1;
      await d.complete('a');
      expect(jsonDecode(disk.durable!), hasLength(1));
      await d.flush();
      expect(sent, isEmpty);
      expect(
        jsonDecode(disk.durable!),
        isEmpty,
        reason:
            'flush after storage recovery must persist the pending deletion',
      );
    },
  );

  test(
    'failed deletion after drain delivery replays again after restart',
    () async {
      disk.durable = jsonEncode([entry('a').toJson()]);
      disk.rejectWrites = 1;
      final d = make();
      await d.start();
      await idle(d);
      expect(sent, ['a']);
      expect(
        await d.pendingCount,
        0,
        reason: 'current memory already forgot delivery',
      );
      expect(jsonDecode(disk.durable!), hasLength(1));
      store = OutboxStore(prefs: disk); // fresh process-like store, same disk
      final restarted = make();
      await restarted.start();
      await idle(restarted);
      expect(sent, [
        'a',
        'a',
      ], reason: 'unacknowledged deletion permits replay after restart');
      expect(jsonDecode(disk.durable!), isEmpty);
    },
  );

  test('failed reserve does not expose an online-owned entry to drain', () async {
    final d = make();
    await d.start();
    disk.rejectWrites = 1;
    expect(await d.reserve(entry('online')), isFalse);
    await d.flush(); // caller may still be sending online after false reserve
    expect(
      sent,
      isEmpty,
      reason:
          'failed append must roll back or retain ownership until online finishes',
    );
  });

  test('disabled queue preserves expired disk entries until enabled', () async {
    disk.durable = jsonEncode([entry('a').toJson()]);
    settings = const OfflineQueueSettings(
      enabled: false,
      maxAge: Duration(seconds: 1),
    );
    final d = make();
    await d.start();
    now = epoch.add(const Duration(seconds: 2));
    await d.flush();
    expect(await d.pendingCount, 1);
    expect(jsonDecode(disk.durable!), hasLength(1));
    settings = const OfflineQueueSettings(maxAge: Duration(seconds: 1));
    d.onSettingsChanged();
    await idle(d);
    expect(sent, isEmpty);
    expect(jsonDecode(disk.durable!), isEmpty);
  });

  test('lowering maxEntries after load drops oldest before delivery', () async {
    disk.durable = jsonEncode(
      ['a', 'b', 'c'].map((id) => entry(id).toJson()).toList(),
    );
    settings = const OfflineQueueSettings(enabled: false);
    final d = make();
    await d.start();
    settings = const OfflineQueueSettings(maxEntries: 1);
    d.onSettingsChanged();
    await idle(d);
    expect(sent, [
      'c',
    ], reason: 'new queue capacity applies to loaded entries too');
  });

  test(
    'new maxAge is checked for next head while previous send is held',
    () async {
      disk.durable = jsonEncode(
        ['a', 'b'].map((id) => entry(id).toJson()).toList(),
      );
      final entered = Completer<void>();
      final finish = Completer<void>();
      final d = make(
        sender: (e) async {
          sent.add(e.id);
          entered.complete();
          await finish.future;
        },
      );
      await d.start();
      await entered.future.timeout(const Duration(seconds: 3));
      now = epoch.add(const Duration(seconds: 2));
      settings = const OfflineQueueSettings(maxAge: Duration(seconds: 1));
      finish.complete();
      await idle(d);
      expect(sent, ['a']);
      expect(await d.pendingCount, 0);
    },
  );

  for (final raw in ['{broken', '{"unexpected":true}', '[null,42,{"v":999}]']) {
    test('corrupt prefs then append repairs durable JSON: $raw', () async {
      disk.durable = raw;
      final d = make();
      await d.start();
      expect(await d.reserve(entry('fresh')), isTrue);
      final restored = OutboxStore(prefs: disk);
      await restored.load();
      expect(restored.snapshot().map((e) => e.id), ['fresh']);
      expect(restored.head!.createdAt, epoch);
      d.release('fresh');
      await idle(d);
      expect(sent, ['fresh']);
    });
  }

  test(
    'disabled flush returns without waiting for an already running send',
    () async {
      final entered = Completer<void>();
      final finish = Completer<void>();
      final d = make(
        sender: (_) async {
          entered.complete();
          await finish.future;
        },
      );
      await d.start();
      await d.enqueue(entry('a'));
      await entered.future.timeout(const Duration(seconds: 3));
      settings = const OfflineQueueSettings(enabled: false);
      final flushing = d.flush();
      try {
        final result = await Future.any([
          flushing.then((_) => 'returned'),
          Future<String>.delayed(
            const Duration(milliseconds: 100),
            () => 'blocked',
          ),
        ]);
        expect(
          result,
          'returned',
          reason: 'disabled flush is documented as a no-op',
        );
      } finally {
        finish.complete();
        await flushing;
        await idle(d);
      }
    },
  );

  test('500 sequential appends preserve FIFO and report timing', () async {
    await store.load();
    final watch = Stopwatch()..start();
    for (var i = 0; i < 500; i++) {
      await store.append(entry('$i'), maxEntries: 500);
    }
    watch.stop();
    final measurement =
        '500 append: ${watch.elapsedMicroseconds} us; '
        '${disk.writes} full JSON writes; memory-backed fake, not device latency';
    // Timing is diagnostic, never a speed threshold.
    // ignore: avoid_print -- intentional benchmark diagnostic from this test.
    print(measurement);
    expect(
      store.snapshot().map((e) => e.id),
      List.generate(500, (i) => '$i'),
      reason: measurement,
    );
    expect(jsonDecode(disk.durable!), hasLength(500), reason: measurement);
  });

  test('HTTP EOF wrapped as unknown retains entry and retries', () async {
    var attempts = 0;
    final d = make(
      sender: (e) async {
        if (++attempts == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/event'),
            type: DioExceptionType.unknown,
            error: const HttpException(
              'Connection closed before full header was received',
            ),
          );
        }
        sent.add(e.id);
      },
    );
    await d.start();
    await d.enqueue(entry('eof'));
    await idle(d);
    expect(
      await d.pendingCount,
      1,
      reason:
          'premature HTTP EOF is uncertain transport delivery, not permanent rejection',
    );
    expect(sent, isEmpty);
    expect(timers, hasLength(1));
    timers.single.fire();
    await idle(d);
    expect(sent, ['eof']);
    expect(await d.pendingCount, 0);
  });
}
