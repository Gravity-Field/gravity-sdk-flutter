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

class _InertTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

/// getContentByGroup and the *WithDetails calls go to the network on their
/// own, without the batcher: two of them right after a resetUser() used to
/// open a session each, and the device ended up with two. They elect one
/// owner now, and an owner that fails takes nobody down with it.
void main() {
  late HttpServer server;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final held = <Completer<void>>[];
  var holdResponses = false;
  var brokenAnswers = 0;
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  PageContext ctx() => const PageContext(type: ContextType.homepage, data: [], location: '/home');
  ContentSettings settings() => ContentSettings();

  Map<String, dynamic>? userOf(Map<String, dynamic> body) => (body['user'] as Map?)?.cast<String, dynamic>();

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
    PackageInfo.setMockInitialValues(
      appName: 'gate-test',
      packageName: 'ai.gravityfield.gatetest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'gate-ua', id: 'gate-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    OutboxDispatcher.timerFactory = (_, _) => _InertTimer();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recorded.add((path: request.uri.path, body: body));
      final broken = brokenAnswers > 0;
      if (broken) brokenAnswers--;
      if (holdResponses) {
        final gate = Completer<void>();
        held.add(gate);
        await gate.future;
      }
      if (broken) {
        request.response.write('not json at all');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': 'server-uid', 'ses': 'server-ses'},
        'campaigns': <Object>[],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'gate-key', section: 'gate-section');
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
    brokenAnswers = 0;
    await GravitySDK.instance.resetUser();
    recorded.clear();
  });

  tearDown(() async {
    holdResponses = false;
    brokenAnswers = 0;
    for (final gate in held) {
      if (!gate.isCompleted) gate.complete();
    }
    held.clear();
  });

  test('two group requests after a reset open one session, not two', () async {
    holdResponses = true;
    final first = GravityRepo.instance.getContentByGroup(
      group: 'group-a',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );
    final second = GravityRepo.instance.getContentByGroup(
      group: 'group-b',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );

    await waitFor(() => held.length == 1, 'the first request must reach the server');
    await settle();
    expect(recorded, hasLength(1), reason: 'the second must wait for the session the first is opening');
    expect(userOf(recorded.single.body), isEmpty, reason: 'the owner starts without a session');

    held.single.complete();
    holdResponses = false;
    await Future.wait([first, second]);

    expect(recorded, hasLength(2));
    expect(userOf(recorded.last.body)?['uid'], 'server-uid');
    expect(userOf(recorded.last.body)?['ses'], 'server-ses');
    expect(SessionManager.instance.sessionId, 'server-ses', reason: 'exactly one session on the device');
  });

  test('a details request that owns the session is followed, not raced, by a group request', () async {
    holdResponses = true;
    final first = GravityRepo.instance.getContentBySelectorWithDetails(
      selector: 'selector-a',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );
    final second = GravityRepo.instance.getContentByCampaignIdWithDetails(
      campaignId: 'campaign-b',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );

    await waitFor(() => held.length == 1, 'the first request must reach the server');
    await settle();
    expect(recorded, hasLength(1), reason: 'the second must wait for the owner');

    held.single.complete();
    holdResponses = false;
    await Future.wait([first, second]);

    expect(recorded, hasLength(2));
    expect(userOf(recorded.last.body)?['ses'], 'server-ses');
    expect(SessionManager.instance.sessionId, 'server-ses');
  });

  test('a failing session owner fails alone and the waiter opens the session itself', () async {
    holdResponses = true;
    brokenAnswers = 1; // only the owner's answer is unusable
    final first = GravityRepo.instance.getContentByGroup(
      group: 'group-a',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );
    final second = GravityRepo.instance.getContentByGroup(
      group: 'group-b',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );

    await waitFor(() => held.length == 1, 'the first request must reach the server');
    await settle();
    expect(recorded, hasLength(1), reason: 'the second must wait for the owner');

    held.single.complete();
    await expectLater(first, throwsA(anything));

    await waitFor(() => held.length == 2, 'the waiter must elect itself and ask for a session');
    held.last.complete();
    holdResponses = false;
    final response = await second;

    expect(response.user.ses, 'server-ses', reason: 'the waiter got a session of its own');
    expect(SessionManager.instance.sessionId, 'server-ses');
  });

  test('a selector request does not fail with the cold /visit it waited for', () async {
    holdResponses = true;
    brokenAnswers = 1; // the /visit answer is unusable
    final visit = GravityRepo.instance.visit(pageContext: ctx(), options: const Options());
    await waitFor(() => held.length == 1, 'the visit must own the session gate');

    final content = GravityRepo.instance.getContentBySelector(
      selector: 'selector-a',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: settings(),
    );
    await settle();
    expect(recorded, hasLength(1), reason: 'the content request waits for the visit');

    held.single.complete();
    await expectLater(visit, throwsA(anything));

    await waitFor(() => held.length == 2, 'the content request must ask for its own session');
    held.last.complete();
    holdResponses = false;
    final response = await content;

    expect(response.user.ses, 'server-ses', reason: 'a foreign failure is not this call to report');
    expect(SessionManager.instance.sessionId, 'server-ses');
  });
}
