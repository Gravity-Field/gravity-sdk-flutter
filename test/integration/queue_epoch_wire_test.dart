import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_entry.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _InertTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

/// Calls [onSerialized] the moment the event is turned into JSON — while the
/// request body is being built, before anything reaches the disk. The one
/// point a test can reach between the start of an event and its reservation.
class _SerializationProbe extends CustomEvent {
  _SerializationProbe(this.onSerialized) : super(type: 'probe-v1', name: 'probe');

  final void Function() onSerialized;

  @override
  Map<String, dynamic> toJson() {
    onSerialized();
    return super.toJson();
  }
}

/// Lets a test stand inside a queue write: [holdNextOutboxWrite] parks the
/// next write of the queue file, [outboxWriteReached] says when it got there,
/// and the value the hold is completed with decides whether the platform then
/// accepts the write or refuses it the way Android does.
class _PlatformDisk extends InMemorySharedPreferencesStore {
  _PlatformDisk() : super.empty();

  Completer<bool>? holdNextOutboxWrite;
  Completer<void>? outboxWriteReached;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('gravity_outbox')) {
      final hold = holdNextOutboxWrite;
      if (hold != null) {
        holdNextOutboxWrite = null;
        outboxWriteReached?.complete();
        outboxWriteReached = null;
        if (!await hold.future) return false;
      }
    }
    return super.setValue(valueType, key, value);
  }

  Future<List<dynamic>> outbox() async {
    final raw = (await getAll())['flutter.gravity_outbox'] as String?;
    return raw == null ? [] : jsonDecode(raw) as List;
  }
}

/// clearQueue() means the queued requests are gone for good. Every step that
/// can suspend between the caller's decision and the wire is a chance for the
/// clear to land, and none of them may let a dropped request out.
void main() {
  late HttpServer server;
  late int deadPort;
  late _PlatformDisk disk;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final originalRetryDelays = Api.retryDelays;
  final originalSleep = Api.sleep;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  Completer<void>? holdVisit;
  Completer<void>? holdEvent;
  var eventStatus = 200;

  PageContext ctx() => const PageContext(type: ContextType.cart, data: [], location: '/cart');

  String live() => 'http://127.0.0.1:${server.port}';
  String dead() => 'http://127.0.0.1:$deadPort';

  List<Map<String, dynamic>> events() =>
      recorded.where((r) => r.path == '/event').map((r) => r.body).toList();

  Future<void> settle() async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> waitFor(FutureOr<bool> Function() condition, String reason) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) fail(reason);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  OutboxEntry anonymousEntry(String id) => OutboxEntry(
    id: id,
    kind: OutboxKind.event,
    createdAt: Clock.now(),
    body: {
      'sec': 'epoch-section',
      'device': {'id': 'epoch-device'},
      'data': [
        {'type': id, 'name': id, 'eventTime': '2026-09-20T10:00:00.000000Z'},
      ],
      'user': <String, dynamic>{},
      'ctx': ctx().toJson(),
      'options': <String, dynamic>{},
    },
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    disk = _PlatformDisk();
    SharedPreferencesStorePlatform.instance = disk;
    PackageInfo.setMockInitialValues(
      appName: 'epoch-test',
      packageName: 'ai.gravityfield.epochtest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'epoch-ua', id: 'epoch-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    OutboxDispatcher.timerFactory = (_, _) => _InertTimer();

    final placeholder = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    deadPort = placeholder.port;
    await placeholder.close(force: true);

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recorded.add((path: request.uri.path, body: body));
      final path = request.uri.path;
      if (path == '/visit') await holdVisit?.future;
      if (path == '/event') await holdEvent?.future;
      if (path == '/event' && eventStatus != 200) {
        request.response.statusCode = eventStatus;
        request.response.write('{"msg":"unavailable"}');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': path == '/visit' ? 'uid-visit' : 'uid-event', 'ses': 'server-ses'},
        'campaigns': <Object>[],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'epoch-key', section: 'epoch-section');
  });

  tearDownAll(() async {
    await server.close(force: true);
    OutboxDispatcher.lifecycleObserverEnabled = true;
    Api.retryDelays = originalRetryDelays;
    Api.sleep = originalSleep;
    OutboxDispatcher.timerFactory = originalTimerFactory;
  });

  setUp(() async {
    recorded.clear();
    holdVisit = null;
    holdEvent = null;
    eventStatus = 200;
    Api.retryDelays = const [];
    Api.sleep = originalSleep;
    disk.holdNextOutboxWrite = null;
    disk.outboxWriteReached = null;
    SessionManager.beforeUserIdWrite = null;
    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings());
    await SessionManager.instance.resetSession();
    await GravitySDK.instance.clearQueue();
    recorded.clear();
  });

  tearDown(() async {
    SessionManager.beforeUserIdWrite = null;
    holdVisit?.complete();
    holdEvent?.complete();
    disk.holdNextOutboxWrite?.complete(true);
    disk.holdNextOutboxWrite = null;
    disk.outboxWriteReached = null;
    Api.retryDelays = const [];
    Api.sleep = originalSleep;
    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings());
  });

  test('a queued event cleared while it waits for the session never reaches the wire', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'waiting-v1', name: 'waiting')],
      pageContext: ctx(),
    );
    expect(await GravitySDK.instance.pendingDeliveries, 1);
    await waitFor(() => !GravityRepo.instance.outbox.isDraining, 'the first attempt must finish');
    GravitySDK.instance.setOptions(proxyUrl: live());

    // A restore holds the gate; the drain parks behind it and then, finding
    // no session, takes the gate itself.
    final holdWrite = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) => holdWrite.future;
    final restore = GravitySDK.instance.restoreUserId('restored-uid');
    await settle();
    final flush = GravitySDK.instance.flushQueue();
    await settle();
    expect(events(), isEmpty, reason: 'the entry is parked behind the restore');

    await GravitySDK.instance.clearQueue();
    holdWrite.complete();
    await restore;
    await flush;

    expect(events(), isEmpty, reason: 'a cleared entry must not be sent when the session arrives');
    expect(await GravitySDK.instance.pendingDeliveries, 0);
    expect(
      SessionManager.instance.isInitializing,
      isFalse,
      reason: 'the gate the cancelled delivery adopted must not stay open',
    );
  });

  test('a clear inside the identity write of an online event stops the send', () async {
    // Cold start: the visit owns the session, the event is built anonymously
    // and learns its identity only after the gate lifts — the write of that
    // identity is where the clear lands.
    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await settle();
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'identity-v1', name: 'identity')],
      pageContext: ctx(),
    );
    await waitFor(() async => await GravitySDK.instance.pendingDeliveries == 1, 'the event must be reserved');

    final reached = Completer<void>();
    final release = Completer<bool>();
    disk.outboxWriteReached = reached;
    disk.holdNextOutboxWrite = release;
    holdVisit!.complete();
    holdVisit = null;
    await reached.future;

    final clearing = GravitySDK.instance.clearQueue();
    await settle();
    release.complete(true);
    await clearing;
    await visit;
    expect(await event, isNull);

    expect(events(), isEmpty, reason: 'the event was dropped while its identity was being written');
    expect(await disk.outbox(), isEmpty);
    expect(await GravitySDK.instance.pendingDeliveries, 0);
    expect(SessionManager.instance.isInitializing, isFalse);
  });

  test('a re-queue waiting for the write chain does not bring a cleared entry back', () async {
    final outbox = GravityRepo.instance.outbox;

    // Occupy the serialized write chain, so the re-queue below has to wait
    // for its turn — the window the online path's own epoch check misses.
    final reached = Completer<void>();
    final release = Completer<bool>();
    disk.outboxWriteReached = reached;
    disk.holdNextOutboxWrite = release;
    final occupier = outbox.enqueue(anonymousEntry('occupier'));
    await reached.future;

    // What event() does when its request failed: hand the event back to the
    // queue it was raised for.
    final epoch = outbox.epoch;
    final requeue = outbox.enqueue(
      anonymousEntry('requeued'),
      precondition: () => outbox.epoch == epoch,
    );
    await settle();

    final clearing = GravitySDK.instance.clearQueue();
    await settle();
    release.complete(true);
    await occupier;

    expect(await requeue, isFalse, reason: 'the queue it belonged to no longer exists');
    await clearing;
    expect(await disk.outbox(), isEmpty, reason: 'nothing came back from the write that was in flight');
    expect(await GravitySDK.instance.pendingDeliveries, 0);
    expect(events(), isEmpty);
  });

  test('a clear cancels an event whose reservation the disk refused', () async {
    // The visit owns the session and the event parks behind it, but its
    // reservation never lands: nothing on disk names the event, so only the
    // queue generation can still tell it that it was dropped.
    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await waitFor(() => recorded.any((r) => r.path == '/visit'), 'the visit must own the gate');

    final reached = Completer<void>();
    final decide = Completer<bool>();
    disk.outboxWriteReached = reached;
    disk.holdNextOutboxWrite = decide;
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'unreserved-v1', name: 'unreserved')],
      pageContext: ctx(),
    );
    await reached.future;

    final clearing = GravitySDK.instance.clearQueue();
    decide.complete(false);
    await clearing;
    holdVisit!.complete();
    holdVisit = null;
    await visit;
    expect(await event, isNull);

    expect(events(), isEmpty, reason: 'a refused reservation must not let an event outlive the clear');
    expect(await GravitySDK.instance.pendingDeliveries, 0);
    expect(SessionManager.instance.isInitializing, isFalse);
  });

  test('a clear cancels an event waiting for its session while the queue is off', () async {
    // Nothing is ever reserved with the queue disabled, and clearQueue() is
    // documented to work in that mode too.
    GravitySDK.instance.setOptions(offlineQueue: const OfflineQueueSettings(enabled: false));
    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await waitFor(() => recorded.any((r) => r.path == '/visit'), 'the visit must own the gate');

    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'unqueued-v1', name: 'unqueued')],
      pageContext: ctx(),
    );
    await settle();
    expect(await GravitySDK.instance.pendingDeliveries, 0, reason: 'a disabled queue holds nothing');

    await GravitySDK.instance.clearQueue();
    holdVisit!.complete();
    holdVisit = null;
    await visit;
    expect(await event, isNull);

    expect(events(), isEmpty, reason: 'the clear covers an event still waiting for its session');
    expect(SessionManager.instance.isInitializing, isFalse);
  });

  test('a clear during the retry pause of an online event cancels the repeat', () async {
    Api.retryDelays = const [Duration(milliseconds: 5)];
    final pausing = Completer<void>();
    final resume = Completer<void>();
    Api.sleep = (_) {
      if (!pausing.isCompleted) pausing.complete();
      return resume.future;
    };
    eventStatus = 503;

    final event = GravityRepo.instance.event(
      events: [CustomEvent(type: 'retried-v1', name: 'retried')],
      pageContext: ctx(),
      options: const Options(),
    );
    await pausing.future;
    expect(events(), hasLength(1), reason: 'the first attempt is on the wire');

    await GravitySDK.instance.clearQueue();
    resume.complete();
    // The caller is told the truth: the event was neither delivered nor
    // queued, because the queue it belonged to was dropped.
    await expectLater(event, throwsA(anything));

    await settle();
    expect(events(), hasLength(1), reason: 'a cleared event is not sent a second time');
    expect(await GravitySDK.instance.pendingDeliveries, 0);
  });

  test('a clear while the event body is being built keeps its reservation off the disk', () async {
    // The visit owns the session, so the event parks behind it after its
    // reservation — the stretch a killed process would leave on disk.
    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await waitFor(() => recorded.any((r) => r.path == '/visit'), 'the visit must own the gate');

    Future<void>? clearing;
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [_SerializationProbe(() => clearing ??= GravitySDK.instance.clearQueue())],
      pageContext: ctx(),
    );
    await waitFor(() => clearing != null, 'the body must be built');
    await clearing;
    await settle();

    expect(
      await disk.outbox(),
      isEmpty,
      reason: 'an event from before the clear must not reach the disk after it: a restart would send it',
    );

    holdVisit!.complete();
    holdVisit = null;
    await visit;
    expect(await event, isNull);
    expect(events(), isEmpty);
    expect(await GravitySDK.instance.pendingDeliveries, 0);
    expect(SessionManager.instance.isInitializing, isFalse);
  });
}
