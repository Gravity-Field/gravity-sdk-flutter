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

/// The dispatcher's real backoff timer would keep these tests waiting for
/// seconds; nothing here relies on it firing.
class _InertTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

Future<void> _until(FutureOr<bool> Function() predicate, String reason) async {
  final watch = Stopwatch()..start();
  while (!await predicate()) {
    if (watch.elapsed > const Duration(seconds: 5)) fail(reason);
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// Requests that wake up behind a restoreUserId() gate must elect a single
/// owner for the session request instead of all going out without a session.
void main() {
  late HttpServer server;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final held = <Completer<void>>[];
  var holdResponses = false;
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  PageContext ctx() => const PageContext(type: ContextType.homepage, data: [], location: '/home');

  Future<List<dynamic>> disk() async {
    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    return raw == null ? [] : jsonDecode(raw) as List;
  }

  setUpAll(() async {
    // Before anything can touch Prefs: initialize() below loads the outbox.
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'election-test',
      packageName: 'ai.gravityfield.electiontest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'election-ua', id: 'election-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    OutboxDispatcher.timerFactory = (_, _) => _InertTimer();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recorded.add((path: request.uri.path, body: body));
      if (holdResponses) {
        final gate = Completer<void>();
        held.add(gate);
        await gate.future;
      }
      final uid = (body['user'] as Map?)?['uid'] as String? ?? 'server-uid';
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': uid, 'ses': 'server-ses'},
        'campaigns': <Object>[],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'election-key', section: 'election-section');
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
    held.clear();
    holdResponses = false;
    SessionManager.beforeUserIdWrite = null;
    await SessionManager.instance.resetSession();
  });

  tearDown(() async {
    SessionManager.beforeUserIdWrite = null;
    GravityRepo.storedUserIdReadOverride = null;
    for (final gate in held) {
      if (!gate.isCompleted) gate.complete();
    }
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
    await GravitySDK.instance.clearQueue();
  });

  test('an event cleared while restore holds the gate must release adopted ownership', () async {
    // The cleared event must never reach transport, even if this test fails.
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:1');
    final enteredWrite = Completer<void>();
    final releaseWrite = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) {
      enteredWrite.complete();
      return releaseWrite.future;
    };
    final restore = GravitySDK.instance.restoreUserId('restored-uid');
    await enteredWrite.future;

    final event = GravityRepo.instance.event(
      events: [CustomEvent(type: 'review-v1', name: 'cancelled')],
      pageContext: ctx(),
      options: const Options(),
    );

    try {
      await _until(
        () async => await GravitySDK.instance.pendingDeliveries == 1,
        'the event did not reach the outbox reservation',
      );
      await Future<void>.delayed(Duration.zero);
      await GravitySDK.instance.clearQueue();
    } finally {
      releaseWrite.complete();
      await restore;
      await event.timeout(const Duration(seconds: 5));
    }

    expect(await GravitySDK.instance.pendingDeliveries, 0);
    expect(recorded, isEmpty);
    expect(
      SessionManager.instance.isInitializing,
      isFalse,
      reason: 'the cancelled event owns no HTTP request and cannot leave a pending session gate',
    );
  });

  test('a failed identity read during owner adoption releases the gate', () async {
    final holdWrite = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) => holdWrite.future;
    final restore = GravitySDK.instance.restoreUserId('restored-uid');
    await Future<void>.delayed(Duration.zero);

    final failing = GravityRepo.instance.visit(pageContext: ctx(), options: Options());
    await Future<void>.delayed(Duration.zero);
    GravityRepo.storedUserIdReadOverride = () => throw StateError('prefs unavailable');
    holdWrite.complete();
    await restore;

    await expectLater(failing, throwsA(isA<StateError>()));
    expect(SessionManager.instance.isInitializing, isFalse, reason: 'the failed adopter must not keep the gate');
    expect(recorded, isEmpty);

    GravityRepo.storedUserIdReadOverride = null;
    await GravityRepo.instance.visit(pageContext: ctx(), options: Options());
    expect(recorded.map((r) => r.path), ['/visit']);
    expect((recorded.single.body['user'] as Map)['uid'], 'restored-uid');
    expect(SessionManager.instance.sessionId, 'server-ses');
  });

  test('two visits parked behind a restore elect one owner and share its session', () async {
    holdResponses = true;
    final holdWrite = Completer<void>();
    SessionManager.beforeUserIdWrite = (_) => holdWrite.future;

    final restore = GravitySDK.instance.restoreUserId('restored-uid');
    await Future<void>.delayed(Duration.zero);
    expect(SessionManager.instance.isInitializing, isTrue, reason: 'the restore write holds the gate');

    final first = GravityRepo.instance.visit(pageContext: ctx(), options: Options());
    final second = GravityRepo.instance.visit(pageContext: ctx(), options: Options());
    await Future<void>.delayed(Duration.zero);
    expect(recorded, isEmpty);

    holdWrite.complete();
    await restore;
    await _until(() => recorded.length == 1, 'exactly one visit must own the session request');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recorded.length, 1, reason: 'the second visit must wait for the owner');
    expect((recorded.single.body['user'] as Map)['uid'], 'restored-uid');
    expect((recorded.single.body['user'] as Map).containsKey('ses'), isFalse);

    held.single.complete();
    holdResponses = false;
    await Future.wait([first, second]);

    expect(recorded.map((r) => r.path), ['/visit', '/visit']);
    expect((recorded.last.body['user'] as Map)['uid'], 'restored-uid');
    expect((recorded.last.body['user'] as Map)['ses'], 'server-ses');
    expect(SessionManager.instance.userId, 'restored-uid');
    expect(SessionManager.instance.sessionId, 'server-ses');
  });

  test('an event raised after a restore is reserved with the restored uid', () async {
    await GravitySDK.instance.restoreUserId('restored-uid');
    holdResponses = true;

    final event = GravityRepo.instance.event(
      events: [CustomEvent(type: 'custom-v1', name: 'x')],
      pageContext: ctx(),
      options: Options(),
    );
    await _until(() async => (await disk()).length == 1, 'the event must be reserved on disk');
    final reservedUser = ((await disk()).single as Map)['body']['user'] as Map;
    expect(reservedUser['uid'], 'restored-uid');

    await _until(() => held.isNotEmpty, 'the event must reach the server');
    held.single.complete();
    holdResponses = false;
    await event;

    expect((recorded.single.body['user'] as Map)['uid'], 'restored-uid');
    expect(await disk(), isEmpty);
    expect(SessionManager.instance.sessionId, 'server-ses');
  });
}
