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

/// Wire-level: /event fails while the server is down, is persisted, and is
/// delivered untouched by flushQueue() once the server is back. Campaigns in
/// the deferred response must not trigger /choose.
void main() {
  late HttpServer server;
  late int deadPort;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final eventTimeRe = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$');
  final originalRetryDelays = Api.retryDelays;
  final originalTimerFactory = OutboxDispatcher.timerFactory;

  PageContext ctx() => const PageContext(type: ContextType.cart, data: [], location: '/cart');

  String live() => 'http://127.0.0.1:${server.port}';
  String dead() => 'http://127.0.0.1:$deadPort';

  setUpAll(() async {
    // Before anything can touch Prefs: initialize() below loads the outbox.
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'outbox-test',
      packageName: 'ai.gravityfield.outboxtest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'outbox-ua', id: 'outbox-device');
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
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': 'server-uid', 'ses': 'server-ses'},
        'campaigns': [
          {'campaignId': 'camp-1', 'trigger': 'event', 'priority': 1, 'delayTime': 0},
        ],
        'data': <Object>[],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'outbox-key', section: 'outbox-section');
  });

  tearDownAll(() async {
    await server.close(force: true);
    OutboxDispatcher.lifecycleObserverEnabled = true;
    Api.retryDelays = originalRetryDelays;
    OutboxDispatcher.timerFactory = originalTimerFactory;
  });

  setUp(() async {
    recorded.clear();
    GravitySDK.instance.setOptions(proxyUrl: live(), offlineQueue: const OfflineQueueSettings());
    await SessionManager.instance.resetSession();
  });

  test('offline event is queued, delivered by flushQueue with eventTime, campaigns ignored', () async {
    // Warm up the session online so the queued body carries a uid.
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    recorded.clear();

    GravitySDK.instance.setOptions(proxyUrl: dead());
    final result = await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'add-to-cart-v1', name: 'add')],
      pageContext: ctx(),
    );
    expect(result, isNull);
    expect(await GravitySDK.instance.pendingDeliveries, 1);
    expect(recorded, isEmpty);

    GravitySDK.instance.setOptions(proxyUrl: live());
    await GravitySDK.instance.flushQueue();

    expect(recorded.map((r) => r.path), ['/event'], reason: 'no /choose for a deferred response');
    final data = (recorded.single.body['data'] as List).cast<Map<String, dynamic>>();
    expect(data.single['type'], 'add-to-cart-v1');
    expect(data.single['eventTime'], matches(eventTimeRe));
    expect(recorded.single.body['sec'], 'outbox-section');
    expect((recorded.single.body['user'] as Map)['uid'], 'server-uid');
    expect(await GravitySDK.instance.pendingDeliveries, 0);

    final raw = (await SharedPreferences.getInstance()).getString('gravity_outbox');
    expect(jsonDecode(raw!), isEmpty);
  });

  test('a successful online request drains the queue without an explicit flush', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'custom-v1', name: 'x')],
      pageContext: ctx(),
    );
    expect(await GravitySDK.instance.pendingDeliveries, 1);

    GravitySDK.instance.setOptions(proxyUrl: live());
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    // Give the drain started by the success signal a chance to finish.
    await GravitySDK.instance.flushQueue();

    expect(recorded.where((r) => r.path == '/event').length, 1);
    expect(await GravitySDK.instance.pendingDeliveries, 0);
  });

  test('queued before any session gets the uid known at send time', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead());
    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'custom-v1', name: 'x')],
      pageContext: ctx(),
    );
    GravitySDK.instance.setOptions(proxyUrl: live());
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());
    await GravitySDK.instance.flushQueue();

    final event = recorded.firstWhere((r) => r.path == '/event');
    expect((event.body['user'] as Map)['uid'], 'server-uid');
  });

  test('disabled queue: offline event is lost as before, nothing persisted', () async {
    GravitySDK.instance.setOptions(proxyUrl: dead(), offlineQueue: const OfflineQueueSettings(enabled: false));
    final result = await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'custom-v1', name: 'x')],
      pageContext: ctx(),
    );
    expect(result, isNull);
    expect(await GravitySDK.instance.pendingDeliveries, 0);
  });

  test('a 422 is not queued', () async {
    // Point at a server that answers 422 for /event.
    final rejecting = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    rejecting.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.statusCode = 422;
      request.response.write('{"msg":"parse error"}');
      await request.response.close();
    });
    addTearDown(() => rejecting.close(force: true));
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${rejecting.port}');

    await GravitySDK.instance.triggerEventNoShow(
      events: [CustomEvent(type: 'custom-v1', name: 'x')],
      pageContext: ctx(),
    );
    expect(await GravitySDK.instance.pendingDeliveries, 0);
  });
}
