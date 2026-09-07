import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:gravity_sdk/src/utils/time_format.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InertTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

/// Wire-level recovery scenarios for a retail app on a flaky network: events
/// raised while the first session request is failing, anonymous entries that
/// are delivered before any `/visit`, a request that hangs, the queue being
/// switched on after start, and the timestamp of an event that had to wait.
void main() {
  late HttpServer server;
  late int deadPort;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;
  final originalNow = Clock.now;

  // Per-test server behaviour.
  Completer<void>? holdVisit;
  Completer<void>? holdEvent;
  var visitStatus = 200;
  var eventStatus = 200;
  var uidForVisit = 'uid-visit';
  var uidForEvent = 'uid-event';
  String? visitRawBody; // when set, /visit answers 200 with this exact text

  PageContext ctx() => const PageContext(type: ContextType.cart, data: [], location: '/cart');

  String live() => 'http://127.0.0.1:${server.port}';
  String dead() => 'http://127.0.0.1:$deadPort';

  Future<void> settle() async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> waitFor(FutureOr<bool> Function() condition, {String? reason}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) fail(reason ?? 'condition not met in time');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  List<Map<String, dynamic>> events() => recorded.where((r) => r.path == '/event').map((r) => r.body).toList();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'recovery-test',
      packageName: 'ai.gravityfield.recoverytest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'recovery-ua', id: 'recovery-device');
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
      if (path == '/visit' && visitRawBody != null) {
        request.response.write(visitRawBody);
        await request.response.close();
        return;
      }
      if (path == '/event' && eventStatus != 200) {
        request.response.statusCode = eventStatus;
        request.response.write('{"msg":"unavailable"}');
        await request.response.close();
        return;
      }
      if (path == '/visit' && visitStatus != 200) {
        request.response.statusCode = visitStatus;
        request.response.write('{"msg":"unavailable"}');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': path == '/visit' ? uidForVisit : uidForEvent, 'ses': 'server-ses'},
        'campaigns': <Object>[],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'recovery-key', section: 'recovery-section');
  });

  tearDownAll(() async {
    await server.close(force: true);
    OutboxDispatcher.lifecycleObserverEnabled = true;
    Api.retryDelays = originalRetryDelays;
    OutboxDispatcher.timerFactory = originalTimerFactory;
  });

  setUp(() async {
    recorded.clear();
    holdVisit = null;
    holdEvent = null;
    visitStatus = 200;
    eventStatus = 200;
    uidForVisit = 'uid-visit';
    uidForEvent = 'uid-event';
    visitRawBody = null;
    Clock.now = originalNow;
    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings());
    await SessionManager.instance.resetSession();
    await (await SharedPreferences.getInstance()).remove('gravity_outbox');
    await GravitySDK.instance.flushQueue();
    recorded.clear();
  });

  tearDown(() {
    Clock.now = originalNow;
  });

  test('events waiting on a failing first /visit are queued, not lost', () async {
    holdVisit = Completer<void>();
    visitStatus = 503;
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await settle(); // /visit owns the session gate now
    final first = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'first-v1', name: 'first')],
      pageContext: ctx(),
    );
    final second = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'second-v1', name: 'second')],
      pageContext: ctx(),
    );
    await settle(); // both events are parked behind the gate
    expect(recorded.map((r) => r.path), ['/visit'], reason: 'the events wait, the visit owns the gate');
    expect(await GravitySDK.instance.pendingDeliveries, 2, reason: 'both are on disk while they wait');
    holdVisit!.complete();
    await Future.wait([visit, first, second]);

    visitStatus = 200;
    await GravitySDK.instance.flushQueue();
    await waitFor(() => events().length == 2, reason: 'both events must reach the server');
    expect(events().map((b) => (b['data'] as List).single['type']), ['first-v1', 'second-v1']);
    expect(await GravitySDK.instance.pendingDeliveries, 0);
    // The first deferred event created the session; the second inherits it.
    expect((events().last['user'] as Map)['uid'], 'uid-event');
  });

  test('an anonymous queued event establishes the session for later requests', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'anon-v1', name: 'anon')],
      pageContext: ctx(),
    );
    expect(await GravitySDK.instance.pendingDeliveries, 1);

    GravitySDK.instance.setOptions(proxyUrl: live());
    await GravitySDK.instance.flushQueue();
    expect(events().single['data'], isNotEmpty);
    expect(await GravitySDK.instance.pendingDeliveries, 0);

    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    final visit = recorded.firstWhere((r) => r.path == '/visit').body;
    expect((visit['user'] as Map)['uid'], 'uid-event', reason: 'the uid the deferred event received is kept');
  });

  test('an event is on disk while its request is still in flight', () async {
    holdEvent = Completer<void>();
    final call = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'inflight-v1', name: 'inflight')],
      pageContext: ctx(),
    );
    await waitFor(() => events().length == 1, reason: 'request reaches the server');

    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    final persisted = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
    expect(persisted, hasLength(1), reason: 'a kill now must not lose the event');
    expect(((persisted.single['body'] as Map)['data'] as List).single['type'], 'inflight-v1');

    holdEvent!.complete();
    await call;
    expect(events(), hasLength(1), reason: 'the outbox must not send it a second time');
    final after = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    expect(jsonDecode(after!), isEmpty);
  });

  test('a form response is on disk before its request completes', () async {
    // Same path as the form submit executor: fire-and-forget event.
    holdEvent = Completer<void>();
    unawaited(
      GravitySDK.instance.triggerEventNoShow(
        events: [CustomEvent(type: 'form-v1', name: 'form', customProps: const {'answer': 'yes'})],
        pageContext: ctx(),
      ),
    );
    await waitFor(() async => (await GravitySDK.instance.pendingDeliveries) == 1);
    holdEvent!.complete();
    await waitFor(() async => (await GravitySDK.instance.pendingDeliveries) == 0);
  });

  test('switching the queue on after start delivers what was queued', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'later-v1', name: 'later')],
      pageContext: ctx(),
    );
    expect(await GravitySDK.instance.pendingDeliveries, 1);
    // The drain the failure woke up is still trying the dead port; switching
    // the queue off does not cancel a send already begun, so let it fail first.
    await waitFor(() => !GravityRepo.instance.outbox.isDraining);

    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings(enabled: false));
    await settle();
    expect(events(), isEmpty);

    GravitySDK.instance.setOptions(offlineQueue: const OfflineQueueSettings());
    await waitFor(() => events().length == 1, reason: 'enabling the queue is itself a wake-up signal');
    await waitFor(() async => !GravityRepo.instance.outbox.isDraining && await GravitySDK.instance.pendingDeliveries == 0);
  });

  test('eventTime is the moment of the call, not the moment the session gate opened', () async {
    final t0 = DateTime.utc(2026, 9, 7, 12);
    holdVisit = Completer<void>();
    Clock.now = () => t0;
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await settle();
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'waited-v1', name: 'waited')],
      pageContext: ctx(),
    );
    await settle();
    Clock.now = () => t0.add(const Duration(seconds: 25));
    holdVisit!.complete();
    await Future.wait([visit, event]);

    final data = (events().single['data'] as List).cast<Map<String, dynamic>>();
    expect(data.single['eventTime'], formatEventTime(t0));
  });

  test('a queued event keeps the user it was raised for, even after the session changes', () async {
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx()); // session: uid-visit
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'owned-v1', name: 'owned')],
      pageContext: ctx(),
    );
    await waitFor(() => !GravityRepo.instance.outbox.isDraining);
    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    final persisted = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
    expect(((persisted.single['body'] as Map)['user'] as Map)['uid'], 'uid-visit', reason: 'identity is on disk');

    // The person logs out; a different user will own the next session.
    await SessionManager.instance.resetSession();
    uidForEvent = 'uid-someone-else';
    GravitySDK.instance.setOptions(proxyUrl: live());
    await GravitySDK.instance.flushQueue();

    expect((events().single['user'] as Map)['uid'], 'uid-visit', reason: 'delivered for the user who raised it');
  });

  test('a permanent failure of the session request another call owns keeps the waiting event', () async {
    holdVisit = Completer<void>();
    visitRawBody = 'not json at all';
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await settle(); // /visit owns the gate
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'survivor-v1', name: 'survivor')],
      pageContext: ctx(),
    );
    // Reserved on disk, then parked behind the gate.
    await waitFor(() async => await GravitySDK.instance.pendingDeliveries == 1);
    await settle();
    holdVisit!.complete();
    await Future.wait([visit, event]);

    expect(events(), isEmpty, reason: 'the event itself was never sent');
    expect(await GravitySDK.instance.pendingDeliveries, 1, reason: 'it is queued, not discarded');

    visitRawBody = null;
    await GravitySDK.instance.flushQueue();
    await waitFor(() => events().length == 1);
    expect((events().single['data'] as List).single['type'], 'survivor-v1');
  });

  test('clearQueue drops queued events for good', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    for (final type in ['drop-1', 'drop-2']) {
      await GravitySDK.instance.triggerEventNoShow(
        events: [CustomEvent(type: type, name: type)],
        pageContext: ctx(),
      );
    }
    expect(await GravitySDK.instance.pendingDeliveries, 2);
    await waitFor(() => !GravityRepo.instance.outbox.isDraining);

    await GravitySDK.instance.clearQueue();

    expect(await GravitySDK.instance.pendingDeliveries, 0);
    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    expect(jsonDecode(raw!), isEmpty);

    GravitySDK.instance.setOptions(proxyUrl: live());
    await GravitySDK.instance.flushQueue();
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    expect(events(), isEmpty, reason: 'nothing comes back from the queue');
  });

  test('resetUser keeps the queue; clearQueue is the explicit way to drop it', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'kept-v1', name: 'kept')],
      pageContext: ctx(),
    );
    await GravitySDK.instance.resetUser();
    expect(await GravitySDK.instance.pendingDeliveries, 1);
    await GravitySDK.instance.clearQueue();
    expect(await GravitySDK.instance.pendingDeliveries, 0);
  });

  test('clearQueue cancels an event still waiting for the session', () async {
    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await settle();
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'cancelled-v1', name: 'cancelled')],
      pageContext: ctx(),
    );
    await waitFor(() async => await GravitySDK.instance.pendingDeliveries == 1);

    await GravitySDK.instance.clearQueue();
    expect(await GravitySDK.instance.pendingDeliveries, 0);

    holdVisit!.complete();
    expect(await event, isNull);
    await visit;
    await settle();
    expect(events(), isEmpty, reason: 'a cleared event is not sent when the session arrives');
  });

  test('an event on the wire during clearQueue finishes but is not re-queued on failure', () async {
    holdEvent = Completer<void>();
    eventStatus = 503;
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'onwire-v1', name: 'onwire')],
      pageContext: ctx(),
    );
    await waitFor(() => events().length == 1);
    await GravitySDK.instance.clearQueue();

    holdEvent!.complete();
    expect(await event, isNull);
    expect(await GravitySDK.instance.pendingDeliveries, 0, reason: 'the failed request does not resurrect itself');
    eventStatus = 200;
    await GravitySDK.instance.flushQueue();
    expect(events(), hasLength(1));
  });

  test('an event raised just before clearQueue is dropped even if it reaches the disk after it', () async {
    // event() suspends before its first write; clearQueue() bumps the queue
    // generation in that gap, so the write lands on an already cleared queue.
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'late-write-v1', name: 'late')],
      pageContext: ctx(),
    );
    final clearing = GravitySDK.instance.clearQueue();
    expect(await event, isNull);
    await clearing;
    await waitFor(() => !GravityRepo.instance.outbox.isDraining);

    expect(events(), isEmpty, reason: 'not sent online');
    expect(await GravitySDK.instance.pendingDeliveries, 0, reason: 'not left for the drain either');
  });
}
