import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
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

/// [holdNextOutboxWrite] parks the next write of the queue file, which is how
/// these tests slip a resetUser() into the middle of an event's preparation.
class _PlatformDisk extends InMemorySharedPreferencesStore {
  _PlatformDisk() : super.empty();

  Completer<void>? holdNextOutboxWrite;
  Completer<void>? outboxWriteReached;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('gravity_outbox')) {
      final hold = holdNextOutboxWrite;
      if (hold != null) {
        holdNextOutboxWrite = null;
        outboxWriteReached?.complete();
        outboxWriteReached = null;
        await hold.future;
      }
    }
    return super.setValue(valueType, key, value);
  }

  Future<List<Map<String, dynamic>>> outbox() async {
    final raw = (await getAll())['flutter.gravity_outbox'] as String?;
    return raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }
}

/// An event belongs to the person who raised it. Whatever the session does
/// afterwards — a logout, a restore, a second user on the same device — the
/// request on the wire and the copy on disk must keep naming that person.
void main() {
  late HttpServer server;
  late int deadPort;
  late _PlatformDisk disk;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  Completer<void>? holdVisit;
  Completer<void>? holdEvent;
  var eventStatus = 200;

  PageContext ctx() => const PageContext(type: ContextType.cart, data: [], location: '/cart');

  String live() => 'http://127.0.0.1:${server.port}';
  String dead() => 'http://127.0.0.1:$deadPort';

  List<Map<String, dynamic>> events() =>
      recorded.where((r) => r.path == '/event').map((r) => r.body).toList();

  String? uidOf(Map<String, dynamic> body) => (body['user'] as Map?)?['uid'] as String?;

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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    disk = _PlatformDisk();
    SharedPreferencesStorePlatform.instance = disk;
    PackageInfo.setMockInitialValues(
      appName: 'owner-test',
      packageName: 'ai.gravityfield.ownertest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'owner-ua', id: 'owner-device');
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

    await GravitySDK.instance.initialize(apiKey: 'owner-key', section: 'owner-section');
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
    eventStatus = 200;
    disk.holdNextOutboxWrite = null;
    disk.outboxWriteReached = null;
    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings());
    await SessionManager.instance.resetSession();
    await GravitySDK.instance.clearQueue();
    recorded.clear();
  });

  tearDown(() async {
    holdVisit?.complete();
    holdEvent?.complete();
    disk.holdNextOutboxWrite?.complete();
    disk.holdNextOutboxWrite = null;
    disk.outboxWriteReached = null;
    eventStatus = 200;
    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings());
  });

  /// Raises an event and holds it on its first queue write, so the caller can
  /// change the session underneath it.
  Future<Future<void>> eventHeldOnItsFirstWrite(String type) async {
    final reached = Completer<void>();
    final release = Completer<void>();
    disk.outboxWriteReached = reached;
    disk.holdNextOutboxWrite = release;
    final call = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: type, name: type)],
      pageContext: ctx(),
    );
    await reached.future;
    return () async {
      release.complete();
      await call;
    }();
  }

  test('an event raised for a signed-in user is sent for that user after a logout', () async {
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx()); // session uid-visit
    expect(SessionManager.instance.userId, 'uid-visit');
    recorded.clear();

    final finish = await eventHeldOnItsFirstWrite('owned-v1');
    await GravitySDK.instance.resetUser();
    await finish;

    expect(events(), hasLength(1));
    expect(uidOf(events().single), 'uid-visit', reason: 'the person who raised it, not the empty session after it');
    expect((events().single['user'] as Map)['ses'], 'server-ses');

    // Naming the old user on the wire is only half of it: the answer to that
    // request belongs to a session the app has signed out of, so nothing from
    // it may be taken back into the current one.
    expect(SessionManager.instance.userId, isNull, reason: 'the logout stands');
    expect(SessionManager.instance.sessionId, isNull);
    recorded.clear();
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    final next = recorded.firstWhere((r) => r.path == '/visit').body;
    expect(next['user'], isEmpty, reason: 'the next request starts from a clean session');
  });

  test('an event kept for the signed-out user does not hold the new session back', () async {
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx()); // session uid-visit
    recorded.clear();

    final finish = await eventHeldOnItsFirstWrite('stale-owner-v1');
    await GravitySDK.instance.resetUser();
    eventStatus = 400;
    holdEvent = Completer<void>();
    final done = finish;
    await waitFor(() => events().isNotEmpty, 'the event must reach the server');
    expect(uidOf(events().single), 'uid-visit');

    // Its answer will not open a session for anyone after the logout, so it
    // may not stand in front of the requests that will.
    expect(SessionManager.instance.isInitializing, isFalse, reason: 'the old event must not own the new gate');
    final uid = GravitySDK.instance.getUserId();
    holdEvent!.complete();
    holdEvent = null;
    await done;
    expect(await uid, isNull, reason: 'the old event failing is not the new session failing');
  });

  test('an event that lost the network keeps its user on disk across a logout', () async {
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx()); // session uid-visit
    recorded.clear();
    GravitySDK.instance.setOptions(proxyUrl: dead());

    final finish = await eventHeldOnItsFirstWrite('queued-v1');
    await GravitySDK.instance.resetUser();
    await finish;
    await waitFor(() => !GravityRepo.instance.outbox.isDraining, 'the failed attempt must finish');

    final stored = await disk.outbox();
    expect(stored, hasLength(1));
    expect(((stored.single['body'] as Map)['user'] as Map)['uid'], 'uid-visit');
  });

  test('a queued anonymous event adopts the session identity and keeps it for later retries', () async {
    // Queued before any session exists: no identity of its own yet.
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'anon-v1', name: 'anon')],
      pageContext: ctx(),
    );
    await waitFor(() => !GravityRepo.instance.outbox.isDraining, 'the failed attempt must finish');
    expect(((await disk.outbox()).single['body'] as Map)['user'], isEmpty);

    // A visit owns the session; the drained entry parks behind it and takes
    // the identity the server hands back.
    GravitySDK.instance.setOptions(proxyUrl: live());
    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await settle();
    eventStatus = 503;
    final flush = GravitySDK.instance.flushQueue();
    await settle();
    expect(events(), isEmpty, reason: 'it waits for the session');
    holdVisit!.complete();
    holdVisit = null;
    await visit;
    await flush;

    expect(uidOf(events().single), 'uid-visit', reason: 'an anonymous entry still gets the session identity');
    final afterFailure = await disk.outbox();
    expect(afterFailure, hasLength(1), reason: 'the 503 leaves it queued');
    expect(((afterFailure.single['body'] as Map)['user'] as Map)['uid'], 'uid-visit', reason: 'identity is on disk now');
    expect(afterFailure.single['attempts'], 1, reason: 'the server failure was counted on the stored entry');

    // Somebody else signs in; the retry still belongs to the first user.
    await GravitySDK.instance.restoreUserId('uid-b');
    eventStatus = 200;
    recorded.clear();
    await GravitySDK.instance.flushQueue();
    await waitFor(() => events().length == 1, 'the retry must reach the server');

    expect(uidOf(events().single), 'uid-visit', reason: 'delivered for the user who raised it');
    expect(await GravitySDK.instance.pendingDeliveries, 0);
  });
}
