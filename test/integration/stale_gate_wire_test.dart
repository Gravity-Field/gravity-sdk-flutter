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
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dispatcher's real backoff timer would keep these tests waiting for
/// seconds; delivery here is driven by flushQueue(), so the timer never has
/// to fire.
class _InertTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

/// A /visit or /event answer that arrives after staleContentTimeout must not
/// be followed by /choose: the screen has most likely changed.
void main() {
  late HttpServer server;
  final recorded = <String>[];
  var visitDelay = Duration.zero;
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  PageContext ctx() => const PageContext(type: ContextType.homepage, data: [], location: '/home');

  setUpAll(() async {
    // Before anything can touch Prefs: initialize() below loads the outbox.
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'stale-test',
      packageName: 'ai.gravityfield.staletest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'stale-ua', id: 'stale-device');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    OutboxDispatcher.timerFactory = (_, _) => _InertTimer();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      recorded.add(request.uri.path);
      if (request.uri.path != '/choose') {
        await Future<void>.delayed(visitDelay);
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': 'server-uid', 'ses': 'server-ses'},
        'campaigns': [
          {'campaignId': 'camp-1', 'trigger': 'screenview', 'priority': 1, 'delayTime': 0},
        ],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'stale-key', section: 'stale-section');
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
    visitDelay = Duration.zero;
    GravitySDK.instance.setOptions(staleContentTimeout: const Duration(seconds: 10));
    await SessionManager.instance.resetSession();
  });

  test('fresh /visit answer is followed by /choose', () async {
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    expect(recorded, ['/visit', '/choose']);
  });

  test('stale /visit answer is not followed by /choose', () async {
    visitDelay = const Duration(milliseconds: 300);
    GravitySDK.instance.setOptions(staleContentTimeout: const Duration(milliseconds: 100));
    final result = await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    expect(result, isNull);
    expect(recorded, ['/visit']);
  });

  test('stale /event answer is not followed by /choose', () async {
    visitDelay = const Duration(milliseconds: 300);
    GravitySDK.instance.setOptions(staleContentTimeout: const Duration(milliseconds: 100));
    final result = await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'custom-v1', name: 'x')],
      pageContext: ctx(),
    );
    expect(result, isNull);
    expect(recorded, ['/event']);
  });
}
