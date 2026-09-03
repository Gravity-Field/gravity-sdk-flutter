import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  const apiKey = 'click-wire-key';
  final recorded = <({String method, String path, String query, String? auth})>[];

  String trackUrl(String kind) => 'http://127.0.0.1:${server.port}/track?type=$kind&contentId=content-click';

  setUpAll(() async {
    ErrorReporter.disableNetworkForTests = true;
    PackageInfo.setMockInitialValues(
      appName: 'click-wire',
      packageName: 'ai.gravityfield.clickwire',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'click-wire-ua', id: 'click-wire-device');

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      recorded.add((
        method: request.method,
        path: request.uri.path,
        query: request.uri.query,
        auth: request.headers.value('authorization'),
      ));
      if (request.method == 'GET') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': 'server-uid', 'ses': 'server-ses'},
        'data': [
          {
            'selector': 'headless_banner',
            'payload': [
              {
                'campaignId': 'camp-click',
                'experienceId': 'exp',
                'variationId': 'var',
                'decisionId': 'dec-click',
                'contents': [
                  {
                    'contentId': 'content-click',
                    'deliveryMethod': 'inline',
                    'contentType': 'json',
                    'variables': {'headless_banner': {'variant': 'B'}},
                    'events': [
                      {'type': 'impression', 'urls': [trackUrl('WIMP')]},
                      {'type': 'click', 'urls': [trackUrl('WCLICK')]},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: apiKey, section: 'click-wire-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(recorded.clear);

  tearDown(() async {
    await SessionManager.instance.resetSession();
  });

  Future<void> waitForGet() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!recorded.any((r) => r.method == 'GET')) {
      if (DateTime.now().isAfter(deadline)) fail('SDK did not GET the click URL within 5 s');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('ContentClickEngagement GETs the click URL with the Bearer header', () async {
    final response = await GravitySDK.instance.getContentBySelectorWithDetails(
      selector: 'headless_banner',
      pageContext: const PageContext(type: ContextType.other, data: [], location: '/click-wire'),
    );
    final campaign = response.data.data.single;
    final content = campaign.payload.single.contents.single;
    expect(recorded.where((r) => r.method == 'GET'), isEmpty, reason: 'nothing must be tracked before the click');

    GravitySDK.instance.sendContentEngagement(ContentClickEngagement(content, campaign));
    await waitForGet();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final gets = recorded.where((r) => r.method == 'GET').toList();
    expect(gets, hasLength(1));
    expect(gets.single.path, '/track');
    expect(gets.single.query, contains('type=WCLICK'));
    expect(gets.single.query, contains('contentId=content-click'));
    expect(gets.single.auth, 'Bearer $apiKey');
  });

  test('a content without a click event sends nothing', () async {
    final response = await GravitySDK.instance.getContentBySelectorWithDetails(
      selector: 'headless_banner',
      pageContext: const PageContext(type: ContextType.other, data: [], location: '/click-wire'),
    );
    final campaign = response.data.data.single;
    final original = campaign.payload.single.contents.single;
    final content = CampaignContent(
      contentId: original.contentId,
      templateSystemName: original.templateSystemName,
      deliveryMethod: original.deliveryMethod,
      contentType: original.contentType,
      variables: original.variables,
      products: original.products,
      events: original.events!.where((e) => e.rawType != 'click').toList(),
    );

    GravitySDK.instance.sendContentEngagement(ContentClickEngagement(content, campaign));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(recorded.where((r) => r.method == 'GET'), isEmpty);
  });
}
