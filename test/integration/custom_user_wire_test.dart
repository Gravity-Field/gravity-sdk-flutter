import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wire-level tests for the identity set via [GravitySDK.setUser]: every
/// request the public SDK sends afterwards, including content requests, must
/// carry `user: {custom, ses}` on the wire, and none of them may carry it once
/// the user is reset or when no user was ever set.
void main() {
  late HttpServer server;
  final recordedBodies = <Map<String, dynamic>>[];
  final recordedRequests = <({String method, String path})>[];
  List<Map<String, dynamic>> nextVisitCampaigns = const [];

  const customUser = {'custom': 'u1', 'ses': 's1'};

  PageContext ctx() => const PageContext(type: ContextType.other, data: [], location: '/custom-user');

  /// Echo contract: a selector item answers with a campaign for that selector,
  /// a campaignId item answers with a selector-less campaign for that id. The
  /// payload has no contents, so nothing is presented and no contentLoaded
  /// engagement GET is fired.
  Map<String, dynamic> campaignFor(Map<String, dynamic> item) {
    final selector = item['selector'] as String?;
    final campaignId = selector != null ? 'camp-$selector' : (item['campaignId'] as String? ?? 'camp-group');
    return <String, dynamic>{
      'selector': selector,
      'payload': [
        {
          'campaignId': campaignId,
          'experienceId': 'exp',
          'variationId': 'var',
          'decisionId': 'dec-$campaignId',
          'contents': <Object>[],
        },
      ],
    };
  }

  Map<String, dynamic> userOf(Map<String, dynamic> body) =>
      ((body['user'] ?? const <String, dynamic>{}) as Map).cast<String, dynamic>();

  List<Map<String, dynamic>> bodiesFor(String path) => [
    for (var i = 0; i < recordedRequests.length; i++)
      if (recordedRequests[i].path == path) recordedBodies[i],
  ];

  /// A pumped host route whose BuildContext the SDK entry points require.
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const Text('Host route');
            },
          ),
        ),
      ),
    );
    return hostContext;
  }

  setUpAll(() async {
    // testWidgets installs a mock HttpClient that answers 400 without any
    // network I/O. Initialise the binding up front and drop that override so
    // every test in this file, plain or widget, reaches the local server.
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    // Must run before the first getContent* call: the delay is baked into the
    // late-final batcher.
    GravityRepo.chooseBatchDelay = const Duration(milliseconds: 20);
    // An unexpected SDK failure must not reach the real error endpoint.
    ErrorReporter.disableNetworkForTests = true;

    PackageInfo.setMockInitialValues(
      appName: 'custom-user-test',
      packageName: 'ai.gravityfield.customusertest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'custom-user-ua', id: 'custom-user-device');

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recordedBodies.add(body);
      recordedRequests.add((method: request.method, path: request.uri.path));

      request.response.headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/visit':
          request.response.write(jsonEncode({
            'user': {'uid': 'server-uid', 'ses': 'server-ses'},
            'campaigns': nextVisitCampaigns,
          }));
        case '/event':
          request.response.write(jsonEncode({
            'user': {'uid': 'server-uid', 'ses': 'server-ses'},
            'campaigns': <Object>[],
          }));
        default:
          final items = (body['data'] as List).cast<Map<String, dynamic>>();
          request.response.write(jsonEncode({
            'user': {'uid': 'server-uid', 'ses': 'server-ses'},
            'data': [for (final item in items) campaignFor(item)],
          }));
      }
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'custom-user-key', section: 'custom-user-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    recordedBodies.clear();
    recordedRequests.clear();
    nextVisitCampaigns = const [];
  });

  tearDown(() async {
    // Clears the custom user and the anonymous session alike.
    await GravitySDK.instance.resetUser();
  });

  group('after setUser every content request carries the custom user', () {
    setUp(() => GravitySDK.instance.setUser('u1', 's1'));

    test('getContentBySelector', () async {
      await GravitySDK.instance.getContentBySelector(selector: 'sel', pageContext: ctx());

      expect(recordedRequests.single, (method: 'POST', path: '/choose'));
      expect(userOf(recordedBodies.single), customUser);
    });

    test('getContentByCampaignId', () async {
      await GravitySDK.instance.getContentByCampaignId(campaignId: 'cid', pageContext: ctx());

      expect(recordedRequests.single, (method: 'POST', path: '/choose'));
      expect(userOf(recordedBodies.single), customUser);
    });

    test('getContentByGroup', () async {
      await GravitySDK.instance.getContentByGroup(group: 'grp', pageContext: ctx());

      expect(recordedRequests.single, (method: 'POST', path: '/choose'));
      expect(userOf(recordedBodies.single), customUser);
    });

    test('getContentBySelectorWithDetails', () async {
      await GravitySDK.instance.getContentBySelectorWithDetails(selector: 'sel-details', pageContext: ctx());

      expect(recordedRequests.single, (method: 'POST', path: '/choose'));
      expect(userOf(recordedBodies.single), customUser);
    });

    test('getContentByCampaignIdWithDetails', () async {
      await GravitySDK.instance.getContentByCampaignIdWithDetails(campaignId: 'cid-details', pageContext: ctx());

      expect(recordedRequests.single, (method: 'POST', path: '/choose'));
      expect(userOf(recordedBodies.single), customUser);
    });

    testWidgets('fetchAnchorContent', (tester) async {
      final context = await pumpHost(tester);

      // runAsync: real HTTP must complete instead of hanging in fake async.
      await tester.runAsync(() async {
        await GravitySDK.instance.fetchAnchorContent(context: context, selector: 'anchor', pageContext: ctx());
      });

      expect(recordedRequests.single, (method: 'POST', path: '/choose'));
      expect((recordedBodies.single['data'] as List).single['selector'], 'anchor');
      expect(userOf(recordedBodies.single), customUser);
    });

    testWidgets('trackView: both /visit and the follow-up /choose carry the same custom identity', (tester) async {
      nextVisitCampaigns = [
        {'campaignId': 'cid-visit', 'trigger': 'view', 'priority': 1, 'delayTime': 0},
      ];
      final context = await pumpHost(tester);

      await tester.runAsync(() async {
        await GravitySDK.instance.trackView(context: context, pageContext: ctx());
      });

      expect(recordedRequests.map((r) => r.path), ['/visit', '/choose']);
      final visit = recordedBodies[0];
      final choose = recordedBodies[1];
      expect(userOf(visit), customUser);
      expect((choose['data'] as List).single['campaignId'], 'cid-visit');
      expect(userOf(choose), customUser);
      expect(userOf(choose)['ses'], userOf(visit)['ses']);
    });
  });

  test('resetUser after setUser: the next /choose has no custom key', () async {
    GravitySDK.instance.setUser('u1', 's1');
    await GravitySDK.instance.getContentBySelector(selector: 'before-reset', pageContext: ctx());
    await GravitySDK.instance.resetUser();

    await GravitySDK.instance.getContentBySelector(selector: 'after-reset', pageContext: ctx());

    final bodies = bodiesFor('/choose');
    expect(bodies, hasLength(2));
    expect(userOf(bodies[0]), customUser);
    // The reset dropped the custom identity and the session alike: the second
    // request goes out cold, carrying neither the custom id nor its session.
    expect(userOf(bodies[1]).containsKey('custom'), isFalse);
    expect(userOf(bodies[1])['ses'], isNot('s1'));
    // ...and the server answer to that cold request re-established the
    // anonymous session.
    expect(await GravitySDK.instance.getUserId(), 'server-uid');
  });

  test('without setUser the /choose user is the anonymous one', () async {
    await GravitySDK.instance.getContentBySelector(selector: 'anon', pageContext: ctx());

    expect(recordedRequests.single, (method: 'POST', path: '/choose'));
    expect(userOf(recordedBodies.single).containsKey('custom'), isFalse);
  });
}
