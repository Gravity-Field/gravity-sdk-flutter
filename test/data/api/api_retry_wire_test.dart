import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Api-level wire tests: real Dio against a local HttpServer, asserting how
/// many requests the transient retry produces.
void main() {
  late HttpServer server;
  late Api api;
  final recorded =
      <({String method, String path, Map<String, dynamic>? body})>[];
  final statusQueue = <int>[];
  final sleeps = <Duration>[];
  var successSignals = 0;

  PageContext ctx() =>
      const PageContext(type: ContextType.other, data: [], location: '/retry');

  setUpAll(() async {
    // Every failed attempt below would otherwise POST a real error report.
    ErrorReporter.disableNetworkForTests = true;

    PackageInfo.setMockInitialValues(
      appName: 'retry-test',
      packageName: 'ai.gravityfield.retrytest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(
      userAgent: 'retry-ua',
      id: 'retry-device',
    );

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      recorded.add((
        method: request.method,
        path: request.uri.path,
        body: raw.isEmpty ? null : jsonDecode(raw) as Map<String, dynamic>,
      ));
      final status = statusQueue.isEmpty ? 200 : statusQueue.removeAt(0);
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'user': {'uid': 'server-uid', 'ses': 'server-ses'},
          'campaigns': <Object>[],
          'data': <Object>[],
        }),
      );
      await request.response.close();
    });

    await GravitySDK.instance.initialize(
      apiKey: 'retry-key',
      section: 'retry-section',
    );
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
    api = Api();
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    recorded.clear();
    statusQueue.clear();
    sleeps.clear();
    successSignals = 0;
    Api.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    GravitySDK.instance.staleContentTimeout = const Duration(seconds: 10);
    Api.sleep = (d) async => sleeps.add(d);
    Api.onRequestSucceeded = () => successSignals++;
    Clock.now = DateTime.now;
  });

  tearDownAll(() {
    Api.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    GravitySDK.instance.staleContentTimeout = const Duration(seconds: 10);
    Api.sleep = (d) => Future<void>.delayed(d);
    Api.onRequestSucceeded = null;
    Clock.now = DateTime.now;
  });

  test('503, 503, 200 -> three requests, result from the third', () async {
    statusQueue.addAll([503, 503]);
    final response = await api.visit(null, ctx(), const Options());
    expect(response.user.uid, 'server-uid');
    expect(recorded.length, 3);
    expect(sleeps, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    expect(successSignals, 1);
  });

  test('permanent 422 -> one request, error propagates, no signal', () async {
    statusQueue.add(422);
    await expectLater(
      api.visit(null, ctx(), const Options()),
      throwsA(isA<DioException>()),
    );
    expect(recorded.length, 1);
    expect(sleeps, isEmpty);
    expect(successSignals, 0);
  });

  test('retries stop after retryDelays are exhausted', () async {
    statusQueue.addAll([503, 503, 503, 503, 503]);
    await expectLater(
      api.visit(null, ctx(), const Options()),
      throwsA(isA<DioException>()),
    );
    expect(recorded.length, 4); // 1 + 3 retries
  });

  test('retries stop when the next delay would cross the budget', () async {
    statusQueue.addAll([503, 503, 503, 503]);
    GravitySDK.instance.staleContentTimeout = const Duration(milliseconds: 1500);
    await expectLater(
      api.visit(null, ctx(), const Options()),
      throwsA(isA<DioException>()),
    );
    // 1s delay fits (t=1s <= 1.5s); the 2s delay would end at 3s > 1.5s.
    expect(recorded.length, 2);
    expect(sleeps, [const Duration(seconds: 1)]);
  });

  test('empty retryDelays disables retries', () async {
    statusQueue.add(503);
    Api.retryDelays = const [];
    await expectLater(
      api.visit(null, ctx(), const Options()),
      throwsA(isA<DioException>()),
    );
    expect(recorded.length, 1);
  });

  test('connection refused is retried', () async {
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close(force: true);
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:$deadPort');
    addTearDown(
      () => GravitySDK.instance.setOptions(
        proxyUrl: 'http://127.0.0.1:${server.port}',
      ),
    );

    Api.retryDelays = const [Duration(milliseconds: 1)];
    await expectLater(
      api.visit(null, ctx(), const Options()),
      throwsA(isA<DioException>()),
    );
    expect(sleeps, [const Duration(milliseconds: 1)]);
  });

  test(
    'a throwing success listener neither fails nor re-sends the request',
    () async {
      Api.onRequestSucceeded = () => throw StateError('listener');

      final response = await api.visit(null, ctx(), const Options());

      expect(response.user.uid, 'server-uid');
      expect(recorded.length, 1);
      expect(sleeps, isEmpty);
    },
  );

  group('buildEventBody', () {
    test(
      'stamps eventTime in UTC on every event and yields plain JSON',
      () async {
        Clock.now = () => DateTime.utc(2026, 8, 28, 11, 0, 0, 5);
        final body = await api.buildEventBody(
          [
            AddToCartEvent(
              value: 10,
              productId: 'p1',
              quantity: 1,
              cart: [
                const CartItem(productId: 'p1', quantity: 1, itemPrice: 10),
              ],
            ),
            CustomEvent(type: 'custom-v1', name: 'x'),
          ],
          const User(uid: 'u1', ses: 's1'),
          ctx(),
          const Options(),
        );
        final data = (body['data'] as List).cast<Map<String, dynamic>>();
        expect(data[0]['eventTime'], '2026-08-28T11:00:00.005Z');
        expect(data[1]['eventTime'], '2026-08-28T11:00:00.005Z');
        // Plain JSON: nested cart items are maps, not CartItem objects.
        expect((data[0]['cart'] as List).first, isA<Map<String, dynamic>>());
        expect(jsonEncode(body), isA<String>());
        expect(body['sec'], 'retry-section');
        expect(body['user'], {'uid': 'u1', 'ses': 's1'});
      },
    );

    test('keeps an eventTime supplied by the event itself', () async {
      Clock.now = () => DateTime.utc(2026, 8, 28, 11);
      final body = await api.buildEventBody(
        [_TimedEvent()],
        null,
        ctx(),
        const Options(),
      );
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      expect(data[0]['eventTime'], '2020-01-01T00:00:00.000Z');
    });
  });

  test(
    'postEventBody sends the body as-is and deferred skips retry and signal',
    () async {
      statusQueue.add(503);
      final body = await api.buildEventBody(
        [CustomEvent(type: 't', name: 'n')],
        null,
        ctx(),
        const Options(),
      );
      await expectLater(
        api.postEventBody(body, deferred: true),
        throwsA(isA<DioException>()),
      );
      expect(recorded.length, 1);
      expect(sleeps, isEmpty);

      recorded.clear();
      await api.postEventBody(body, deferred: true);
      expect(recorded.single.path, '/event');
      expect(recorded.single.body!['data'], body['data']);
      expect(successSignals, 0);
    },
  );
}

class _TimedEvent implements TriggerEvent {
  @override
  String get type => 'timed-v1';
  @override
  String get name => 'timed';
  @override
  Map<String, String>? get customProps => null;
  @override
  DateTime? get eventTime => DateTime.utc(2020);
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'eventTime': '2020-01-01T00:00:00.000Z',
  };
}
