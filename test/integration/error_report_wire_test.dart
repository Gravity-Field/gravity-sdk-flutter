import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Error reports raised by real failed requests: whatever the server
/// answered and whatever the query of the URL carried stays on the device.
void main() {
  late HttpServer server;
  final reports = <Map<String, dynamic>>[];
  // Content requests answer 200 with a body that is not valid JSON.
  var malformedAnswer = false;

  PageContext ctx() => const PageContext(type: ContextType.other, data: [], location: '/errors');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'error-report-test',
      packageName: 'ai.gravityfield.errorreporttest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'error-ua', id: 'error-device');
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path == '/pixel') {
        request.response.statusCode = 500;
        request.response.write('{"uid":"pixel-body-uid"}');
      } else if (malformedAnswer) {
        // Dio's JSON decoder fails on this, and a FormatException quotes the
        // source it choked on.
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"uid":"malformed-body-uid",}');
      } else {
        // A refusal that quotes what the server knows about the user.
        request.response.statusCode = 422;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"error":"unknown user","uid":"leaked-body-uid"}');
      }
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'error-key', section: 'error-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
    OutboxDispatcher.lifecycleObserverEnabled = true;
    ErrorReporter.sendOverride = null;
  });

  setUp(() {
    malformedAnswer = false;
    reports.clear();
    ErrorReporter.sendOverride = reports.add;
  });

  test('the body of a refused content request reaches no report', () async {
    await expectLater(
      GravitySDK.instance.getContentBySelector(selector: 'broken', pageContext: ctx()),
      throwsA(anything),
    );
    await GravitySDK.instance.trackViewNoShow(pageContext: ctx());

    expect(reports, isNotEmpty);
    for (final report in reports) {
      expect(jsonEncode(report), isNot(contains('leaked-body-uid')), reason: '${report['tags']}');
    }
  });

  test('a content answer that is not valid JSON reaches no report', () async {
    malformedAnswer = true;
    await expectLater(
      GravitySDK.instance.getContentByGroup(group: 'broken-json', pageContext: ctx()),
      throwsA(anything),
    );

    expect(reports, isNotEmpty);
    for (final report in reports) {
      expect(jsonEncode(report), isNot(contains('malformed-body-uid')), reason: '${report['tags']}');
    }
  });

  test('a failed tracking pixel is reported without its query or body', () async {
    final pixel = 'http://127.0.0.1:${server.port}/pixel';
    await GravitySDK.instance.triggerTrackingUrl('$pixel?type=WCLICK&uid=pixel-query-uid');

    expect(reports, isNotEmpty);
    for (final report in reports) {
      final encoded = jsonEncode(report);
      expect(encoded, isNot(contains('pixel-query-uid')), reason: '${report['tags']}');
      expect(encoded, isNot(contains('pixel-body-uid')), reason: '${report['tags']}');
    }
    final fromInterceptor = reports.firstWhere((r) => r['extra']['httpStatus'] == 500);
    expect((fromInterceptor['tags'] as Map)['section'], 'Api.$pixel');
    expect(fromInterceptor['extra']['url'], pixel);
  });
}
