import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_store.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _ManualTimer implements Timer {
  _ManualTimer(this.callback);
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

class _PlatformDisk extends InMemorySharedPreferencesStore {
  _PlatformDisk() : super.empty();
  int rejectOutboxWrites = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('gravity_outbox') && rejectOutboxWrites > 0) {
      rejectOutboxWrites--;
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  Future<List<dynamic>> outbox() async {
    final raw = (await getAll())['flutter.gravity_outbox'] as String?;
    return raw == null ? [] : jsonDecode(raw) as List;
  }
}

class _BrokenEvent extends TriggerEvent {
  @override
  String get type => 'broken';
  @override
  String get name => 'broken';
  @override
  Map<String, dynamic> toJson() => throw StateError('event serializer failed');
}

Future<void> _until(FutureOr<bool> Function() predicate, String reason) async {
  final watch = Stopwatch()..start();
  while (!await predicate()) {
    if (watch.elapsed > const Duration(seconds: 5)) fail(reason);
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  final sdk = GravitySDK.instance;
  final recorded =
      <({String server, String path, Map<String, dynamic> body})>[];
  final timers = <_ManualTimer>[];
  final held = <Completer<void>>[];
  final oldRetry = Api.retryDelays;
  final oldTimer = OutboxDispatcher.timerFactory;
  final oldLifecycle = OutboxDispatcher.lifecycleObserverEnabled;
  final oldReporting = ErrorReporter.disableNetworkForTests;
  final oldNow = Clock.now;
  final oldPlatform = SharedPreferencesStorePlatform.instance;
  late _PlatformDisk disk;
  late HttpServer serverA;
  late HttpServer serverB;
  Completer<void>? holdEvent;
  Completer<void>? holdVisit;
  int eventStatus = 200;
  int severResponses = 0;

  PageContext ctx() => const PageContext(
    type: ContextType.cart,
    data: [],
    location: '/adversarial',
  );
  String url(HttpServer server) => 'http://127.0.0.1:${server.port}';
  List<Map<String, dynamic>> events() =>
      recorded.where((r) => r.path == '/event').map((r) => r.body).toList();
  Completer<void> barrier() {
    final c = Completer<void>();
    held.add(c);
    return c;
  }

  Future<void> idle() => _until(
    () => !GravityRepo.instance.outbox.isDraining,
    'drain must finish',
  );
  Future<void> empty() => _until(
    () async =>
        !GravityRepo.instance.outbox.isDraining &&
        await sdk.pendingDeliveries == 0,
    'queue must be empty after acknowledged responses',
  );
  Future<void> event(String type, {DateTime? eventTime}) async {
    await sdk.triggerEventNoShow(
      events: [CustomEvent(type: type, name: type, eventTime: eventTime)],
      pageContext: ctx(),
    );
  }

  OutboxEntry anonymous(String id) => OutboxEntry(
    id: id,
    kind: OutboxKind.event,
    createdAt: Clock.now(),
    body: {
      'sec': 'adversarial-section',
      'device': {'id': 'wire-device'},
      'data': [
        {'type': id, 'name': id, 'eventTime': '2026-09-07T10:00:00.123456Z'},
      ],
      'user': <String, dynamic>{},
      'ctx': ctx().toJson(),
      'options': <String, dynamic>{},
    },
  );

  Future<HttpServer> serve(String name) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      recorded.add((server: name, path: request.uri.path, body: body));
      final path = request.uri.path;
      // Capture behaviour at request admission, so a later test change only
      // affects the next request.
      final status = path == '/event' ? eventStatus : 200;
      final sever = path == '/event' && severResponses > 0;
      if (sever) severResponses--;
      final hold = path == '/event' ? holdEvent : holdVisit;
      await hold?.future;
      if (sever) {
        // Body was consumed/accepted; terminate TCP before writing a response.
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          status == 200
              ? {
                  'user': {
                    'uid': path == '/event' ? 'uid-event' : 'uid-visit',
                    'ses': 'wire-ses',
                  },
                  'campaigns': <Object>[],
                  'data': <Object>[],
                }
              : {'message': 'outage'},
        ),
      );
      await request.response.close();
    });
    return server;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    disk = _PlatformDisk();
    SharedPreferencesStorePlatform.instance = disk;
    PackageInfo.setMockInitialValues(
      appName: 'adversarial',
      packageName: 'test.adversarial',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(
      userAgent: 'wire-ua',
      id: 'wire-device',
    );
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    OutboxDispatcher.timerFactory = (_, cb) {
      final t = _ManualTimer(cb);
      timers.add(t);
      return t;
    };
    Api.retryDelays = const [];
    serverA = await serve('A');
    serverB = await serve('B');
    sdk.setOptions(proxyUrl: url(serverA));
    await sdk.initialize(
      apiKey: 'adversarial-key',
      section: 'adversarial-section',
      logLevel: LogLevel.none,
    );
  });
  setUp(() async {
    disk.rejectOutboxWrites = 0;
    holdEvent = null;
    holdVisit = null;
    eventStatus = 200;
    severResponses = 0;
    Clock.now = oldNow;
    sdk.setOptions(
      proxyUrl: url(serverA),
      offlineQueue: const OfflineQueueSettings(),
    );
    await sdk.flushQueue();
    await empty();
    await sdk.resetUser();
    recorded.clear();
    timers.clear();
  });
  tearDown(() async {
    for (final c in held) {
      if (!c.isCompleted) c.complete();
    }
    held.clear();
    holdEvent = null;
    holdVisit = null;
    disk.rejectOutboxWrites = 0;
    eventStatus = 200;
    severResponses = 0;
    Clock.now = oldNow;
    sdk.setOptions(
      proxyUrl: url(serverA),
      offlineQueue: const OfflineQueueSettings(),
    );
    await idle();
    await sdk.flushQueue();
    await empty();
    for (final t in timers) {
      t.cancel();
    }
  });
  tearDownAll(() async {
    await serverA.close(force: true);
    await serverB.close(force: true);
    Api.retryDelays = oldRetry;
    OutboxDispatcher.timerFactory = oldTimer;
    OutboxDispatcher.lifecycleObserverEnabled = oldLifecycle;
    ErrorReporter.disableNetworkForTests = oldReporting;
    Clock.now = oldNow;
    SharedPreferencesStorePlatform.instance = oldPlatform;
    DeviceUtils.instance.debugDevice = null;
  });

  test(
    'accepted body with severed response is replayed: duplicate is expected',
    () async {
      severResponses = 1;
      await event('ambiguous');
      await empty();
      expect(
        events(),
        hasLength(2),
        reason:
            'at-least-once transport cannot know the first request was accepted',
      );
      expect(
        events().last,
        events().first,
        reason: 'frozen body survives uncertain delivery',
      );
      expect(await disk.outbox(), isEmpty);
    },
  );

  test('anonymous drain owns gate while visit and online event wait', () async {
    holdEvent = barrier();
    await GravityRepo.instance.outbox.enqueue(anonymous('deferred-owner'));
    await _until(
      () => events().length == 1,
      'deferred request must own gate on the wire',
    );
    expect(SessionManager.instance.isInitializing, isTrue);
    final visit = sdk.trackViewNoShow(pageContext: ctx());
    final online = event('online-waiter');
    try {
      // This is only a negative observation. Completion, wire order and uid
      // assertions below provide the positive synchronization proof.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(recorded, hasLength(1));
    } finally {
      holdEvent!.complete();
      await Future.wait([visit, online]).timeout(const Duration(seconds: 5));
    }
    await empty();
    expect(recorded, hasLength(3));
    for (final r in recorded.skip(1)) {
      expect((r.body['user'] as Map)['uid'], 'uid-event');
    }
    expect(events().map((b) => (b['data'] as List).single['type']), [
      'deferred-owner',
      'online-waiter',
    ]);
    expect(SessionManager.instance.isInitializing, isFalse);
  });

  test(
    'visit owns gate and anonymous drain adopts its identity without deadlock',
    () async {
      holdVisit = barrier();
      final visit = sdk.trackViewNoShow(pageContext: ctx());
      await _until(
        () => recorded.any((r) => r.path == '/visit'),
        'visit must reach server',
      );
      await GravityRepo.instance.outbox.enqueue(anonymous('waits-for-visit'));
      final flushing = sdk.flushQueue();
      try {
        expect(SessionManager.instance.isInitializing, isTrue);
        expect(events(), isEmpty);
      } finally {
        holdVisit!.complete();
        await Future.wait([
          visit,
          flushing,
        ]).timeout(const Duration(seconds: 5));
      }
      await empty();
      expect(events(), hasLength(1));
      expect((events().single['user'] as Map)['uid'], 'uid-visit');
    },
  );

  test(
    'disabling queue during retryable online failure preserves reserved event',
    () async {
      holdEvent = barrier();
      eventStatus = 503;
      final online = event('disabled-inflight');
      await _until(() => events().length == 1, 'online request must be held');
      expect(await disk.outbox(), hasLength(1));
      sdk.setOptions(offlineQueue: const OfflineQueueSettings(enabled: false));
      holdEvent!.complete();
      await online;
      expect(
        await disk.outbox(),
        hasLength(1),
        reason: 'disabled keeps entries already on disk',
      );
      eventStatus = 200;
      sdk.setOptions(offlineQueue: const OfflineQueueSettings());
      await empty();
      expect(events(), hasLength(2));
    },
  );

  test(
    'rejected reservation cannot cause concurrent online and drain delivery',
    () async {
      // Warm identity lets an accidental drain reach HTTP instead of waiting
      // behind the online call's first-session gate.
      await SessionManager.instance.saveUser(
        null,
        const User(uid: 'warm', ses: 'warm-ses'),
        SessionManager.instance.generation,
      );
      disk.rejectOutboxWrites = 1;
      holdEvent = barrier();
      final online = event('failed-reservation');
      await _until(() => events().length == 1, 'online request must be held');
      expect(
        await disk.outbox(),
        isEmpty,
        reason: 'platform really rejected reservation',
      );
      final flushing = sdk.flushQueue();
      try {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      } finally {
        holdEvent!.complete();
        await Future.wait([
          online,
          flushing,
        ]).timeout(const Duration(seconds: 5));
      }
      await empty();
      expect(
        events(),
        hasLength(1),
        reason: 'failed reservation must not leave an unowned ghost in store',
      );
    },
  );

  test(
    'explicit microsecond eventTime survives persistence reload and replay',
    () async {
      final raised = DateTime.utc(2026, 9, 7, 10, 0, 0, 123);
      final explicit = DateTime.parse('2026-09-07T16:59:58.987654+07:00');
      Clock.now = () => raised;
      eventStatus = 503;
      await event('microseconds', eventTime: explicit);
      await idle();
      expect(await sdk.pendingDeliveries, 1);
      final restored = OutboxStore(prefs: Prefs.forTesting());
      await restored.load();
      expect(restored.head!.createdAt, raised);
      expect(
        (restored.head!.body!['data'] as List).single['eventTime'],
        '2026-09-07T09:59:58.987654Z',
      );
      final frozen = restored.head!.body;
      Clock.now = () => raised.add(const Duration(hours: 1));
      eventStatus = 200;
      timers.lastWhere((t) => t.isActive).fire();
      await empty();
      expect(events().last, frozen);
    },
  );

  test(
    'setOptions proxyUrl after start redirects next replay to new server',
    () async {
      eventStatus = 503;
      await event('redirect');
      await idle();
      expect(recorded.every((r) => r.server == 'A'), isTrue);
      final before = recorded.length;
      sdk.setOptions(proxyUrl: url(serverB));
      eventStatus = 200;
      await sdk.flushQueue();
      await empty();
      expect(recorded.skip(before).map((r) => r.server), ['B']);
      expect((recorded.last.body['data'] as List).single['type'], 'redirect');
    },
  );

  test(
    'repeated initialize while drain owns gate does not create another drain',
    () async {
      holdEvent = barrier();
      await GravityRepo.instance.outbox.enqueue(anonymous('initialize-twice'));
      await _until(() => events().length == 1, 'drain must be held on server');
      try {
        await sdk
            .initialize(
              apiKey: 'adversarial-key',
              section: 'adversarial-section',
              logLevel: LogLevel.none,
            )
            .timeout(const Duration(seconds: 2));
        expect(events(), hasLength(1));
        expect(await sdk.pendingDeliveries, 1);
      } finally {
        holdEvent!.complete();
      }
      await empty();
      expect(events(), hasLength(1));
      expect(SessionManager.instance.isInitializing, isFalse);
    },
  );

  test(
    'flushQueue empty and disabled sends nothing and preserves disk',
    () async {
      await sdk.flushQueue();
      expect(recorded, isEmpty);
      await GravityRepo.instance.outbox.reserve(anonymous('disabled-queued'));
      sdk.setOptions(offlineQueue: const OfflineQueueSettings(enabled: false));
      GravityRepo.instance.outbox.release('disabled-queued');
      await sdk.flushQueue();
      expect(recorded, isEmpty);
      expect(await sdk.pendingDeliveries, 1);
      expect(await disk.outbox(), hasLength(1));
      sdk.setOptions(offlineQueue: const OfflineQueueSettings());
      await empty();
      expect(events(), hasLength(1));
    },
  );

  test('event waiting on visit is persisted before visit responds', () async {
    holdVisit = barrier();
    final visit = sdk.trackViewNoShow(pageContext: ctx());
    await _until(
      () => recorded.any((r) => r.path == '/visit'),
      'visit must own gate',
    );
    final online = event('crash-during-init');
    try {
      // The body is assembled asynchronously (device, package info) before it
      // is written, so give the write a moment; the visit is still held.
      await _until(
        () async => (await disk.outbox()).length == 1,
        'killing the process while event waits for session must preserve the event',
      );
      expect(recorded.map((r) => r.path), ['/visit'], reason: 'the event is still waiting');
    } finally {
      holdVisit!.complete();
      await Future.wait([visit, online]).timeout(const Duration(seconds: 5));
    }
    await empty();
  });

  test(
    'fallback serialization error leaves failure and no phantom queued event',
    () async {
      final gate = SessionManager.instance.beginSessionInitialization();
      final failing = GravityRepo.instance.event(
        events: [_BrokenEvent()],
        pageContext: ctx(),
        options: Options(),
      );
      // The body is frozen before the call waits for the session, so an
      // unserialisable event fails on its own error, not on the gate's.
      final assertion = expectLater(failing, throwsA(isA<StateError>()));
      SessionManager.instance.failSessionInitialization(
        gate,
        const SocketException('initializer failed'),
        StackTrace.current,
      );
      await assertion;
      expect(await sdk.pendingDeliveries, 0);
      expect(await disk.outbox(), isEmpty);
      expect(recorded, isEmpty);
      expect(SessionManager.instance.isInitializing, isFalse);
    },
  );
}
