import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
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
/// these tests stop an event between its identity snapshot and the wire.
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

/// A uid left on the device by an earlier launch is an identity too. Until the
/// first server answer nothing caches it, so an event raised on a cold start
/// used to go out anonymous the moment the app signed the user out mid-flight.
void main() {
  late HttpServer server;
  late _PlatformDisk disk;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  Completer<void>? holdVisit;
  Completer<void>? holdEvent;

  PageContext ctx() => const PageContext(type: ContextType.cart, data: [], location: '/cart');

  List<Map<String, dynamic>> events() =>
      recorded.where((r) => r.path == '/event').map((r) => r.body).toList();

  Map<String, dynamic> userOf(Map<String, dynamic> body) => (body['user'] as Map).cast<String, dynamic>();

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
      appName: 'cold-start-test',
      packageName: 'ai.gravityfield.coldstarttest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'cold-ua', id: 'cold-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    OutboxDispatcher.timerFactory = (_, _) => _InertTimer();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recorded.add((path: request.uri.path, body: body));
      final path = request.uri.path;
      if (path == '/visit') await holdVisit?.future;
      if (path == '/event') await holdEvent?.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': path == '/visit' ? 'uid-visit' : 'uid-event', 'ses': 'server-ses'},
        'campaigns': <Object>[],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'cold-key', section: 'cold-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
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
    disk.holdNextOutboxWrite = null;
    disk.outboxWriteReached = null;
    SessionManager.beforeUserIdWrite = null;
    GravityRepo.storedUserIdReadOverride = null;
    GravitySDK.instance.setOptions(offlineQueue: const OfflineQueueSettings());
    await SessionManager.instance.resetSession();
    await GravitySDK.instance.clearQueue();
    // What an earlier launch left behind.
    await Prefs.instance.setUserId('uid-a');
    recorded.clear();
  });

  tearDown(() async {
    SessionManager.beforeUserIdWrite = null;
    GravityRepo.storedUserIdReadOverride = null;
    holdVisit?.complete();
    holdEvent?.complete();
    disk.holdNextOutboxWrite?.complete();
    disk.holdNextOutboxWrite = null;
    disk.outboxWriteReached = null;
  });

  /// Raises an event and parks it on the write that reserves it, so the caller
  /// can change the user underneath a snapshot that is already taken.
  Future<({Future<void> finish, Completer<void> release})> eventHeldOnReservation(String type) async {
    final reached = Completer<void>();
    final release = Completer<void>();
    disk.outboxWriteReached = reached;
    disk.holdNextOutboxWrite = release;
    final call = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: type, name: type)],
      pageContext: ctx(),
    );
    await reached.future;
    return (finish: call.then((_) {}), release: release);
  }

  test('an event raised with the uid from the device stays that user through a logout', () async {
    expect(await GravitySDK.instance.getUserId(), 'uid-a');
    expect(SessionManager.instance.hasSession, isFalse);

    holdEvent = Completer<void>();
    final held = await eventHeldOnReservation('owned-v1');
    await GravitySDK.instance.resetUser();
    held.release.complete();

    await waitFor(() => events().isNotEmpty, 'the event must reach the server');
    final persisted = await disk.outbox();
    expect(persisted, hasLength(1), reason: 'it is on disk while it is on the wire');
    expect(((persisted.single['body'] as Map)['user'] as Map)['uid'], 'uid-a');

    holdEvent!.complete();
    holdEvent = null;
    await held.finish;

    expect(userOf(events().single)['uid'], 'uid-a', reason: 'the user it was raised for');
    expect(SessionManager.instance.userId, isNull, reason: 'the answer belongs to a session the app left');
    expect(SessionManager.instance.sessionId, isNull);

    // And the app really starts over: the next request carries nothing.
    recorded.clear();
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    final visit = recorded.firstWhere((r) => r.path == '/visit').body;
    expect(visit['user'], isEmpty);
    expect(SessionManager.instance.userId, 'uid-visit');
  });

  test('an event raised after a logout began does not belong to the user being dropped', () async {
    expect(await GravitySDK.instance.getUserId(), 'uid-a');

    // The reset's removal queues behind a uid write that is held, so the reset
    // is under way but the device still holds uid-a when the event is raised.
    final holdWrite = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) => holdWrite.future;
    final stale = SessionManager.instance.saveUser(
      null,
      const User(uid: 'uid-stale', ses: 'stale-ses'),
      SessionManager.instance.generation,
    );
    await settle();
    final reset = GravitySDK.instance.resetUser();
    await settle();

    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'after-reset-v1', name: 'after')],
      pageContext: ctx(),
    );

    // The reservation happens before the event parks behind the reset, and it
    // is what a process killed right here would leave behind.
    await waitFor(
      () async => await GravitySDK.instance.pendingDeliveries == 1,
      'the event must be reserved',
    );
    expect(
      ((await disk.outbox()).single['body'] as Map)['user'],
      isEmpty,
      reason: 'the logout was already under way, so there is no user to freeze',
    );

    holdWrite.complete();
    SessionManager.beforeUserIdWrite = null;
    await Future.wait([stale, reset]);
    await event;

    expect(userOf(events().single)['uid'], isNull);
    expect(SessionManager.instance.userId, 'uid-event', reason: 'the event opened the session that follows it');
  });

  test('an event raised with the uid from the device is not handed to a restored user', () async {
    expect(await GravitySDK.instance.getUserId(), 'uid-a');

    final held = await eventHeldOnReservation('restored-v1');
    await GravitySDK.instance.restoreUserId('uid-b');
    held.release.complete();
    await held.finish;

    expect(userOf(events().single)['uid'], 'uid-a', reason: 'it was not uid-b who raised it');
    expect(SessionManager.instance.userId, 'uid-b', reason: 'the restore stands');
    expect(SessionManager.instance.sessionId, isNull, reason: 'and the event did not open a session for it');
  });

  // Regression guard, green before and after: while the user does not change,
  // the server stays authoritative and the bytes on the wire must not move.
  test('without a logout the waiting event takes the identity the server assigned', () async {
    expect(await GravitySDK.instance.getUserId(), 'uid-a');

    holdVisit = Completer<void>();
    final visit = GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await waitFor(() => recorded.any((r) => r.path == '/visit'), 'the visit must own the gate');
    final event = GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'waiting-v1', name: 'waiting')],
      pageContext: ctx(),
    );
    await settle();
    expect(events(), isEmpty, reason: 'it waits for the session');

    holdVisit!.complete();
    holdVisit = null;
    await visit;
    await event;

    expect(userOf(events().single)['uid'], 'uid-visit', reason: 'the server replaced the stored user');
    expect(userOf(events().single)['ses'], 'server-ses');
  });

  test('a read that finished after a restore cannot put the old uid back', () async {
    final session = SessionManager.instance;
    expect(await GravitySDK.instance.getUserId(), 'uid-a');
    expect(session.observedUser?.uid, 'uid-a');

    // A read of storage that began before the restore and answers after it:
    // the generation it carries is the one it was started under.
    final startedUnder = session.generation;
    await GravitySDK.instance.restoreUserId('uid-b');
    session.noteObservedUserId('uid-a', startedUnder);

    expect(
      session.observedUser?.uid,
      isNot('uid-a'),
      reason: 'the restore has already said who the user is',
    );

    // And the event that follows belongs to the restored user, not to the one
    // the late answer named.
    recorded.clear();
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'after-restore-v1', name: 'after')],
      pageContext: ctx(),
    );
    expect(userOf(events().single)['uid'], 'uid-b');
  });

  test('a read that races a logout cannot bring the dropped uid back', () async {
    final session = SessionManager.instance;

    // The read starts first and is still on its way when the logout begins.
    final read = GravitySDK.instance.getUserId();
    await GravitySDK.instance.resetUser();
    await read;

    expect(session.observedUser, isNull, reason: 'the logout has said there is no user');

    recorded.clear();
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'after-logout-v1', name: 'after')],
      pageContext: ctx(),
    );
    expect(userOf(events().single)['uid'], isNot('uid-a'));
  });
}
