import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/prefs/prefs.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wire-level tests: real GravityRepo -> RequestBatcher -> Api -> HTTP against
/// a local server (via proxyUrl), asserting how many POST /choose calls go out
/// and what their data[] arrays contain.
void main() {
  late HttpServer server;
  final recordedBodies = <Map<String, dynamic>>[];
  final recordedRequests = <({String method, String path})>[];
  var respondWithStatus = 200;
  List<Map<String, dynamic>>? nextResponseCampaigns;
  Duration? nextResponseDelay;

  Map<String, dynamic> payloadFor(String campaignId, {String decisionId = 'dec'}) => {
    'campaignId': campaignId,
    'experienceId': 'exp',
    'variationId': 'var',
    'decisionId': decisionId,
    'contents': <Object>[],
  };

  PageContext ctx() => const PageContext(type: ContextType.other, data: [], location: '/wire');

  // GravityRepo.instance must not be touched before setUpAll: constructing
  // Api() reads the talker logger, which initialize() configures.
  Future<ContentResponse> choose(
    String selector, {
    ContentSettings contentSettings = const ContentSettings(),
    User? customUser,
    List<RtRule>? rules,
    PageContext? pageContext,
  }) {
    return GravityRepo.instance.getContentBySelector(
      selector: selector,
      customUser: customUser,
      pageContext: pageContext ?? ctx(),
      options: const Options(),
      contentSetting: contentSettings,
      rules: rules,
    );
  }

  setUpAll(() async {
    // Must run before the first getContent* call: the delay is baked into the
    // late-final batcher. A wide window keeps concurrent test calls merged.
    GravityRepo.chooseBatchDelay = const Duration(milliseconds: 80);

    PackageInfo.setMockInitialValues(
      appName: 'wire-test',
      packageName: 'ai.gravityfield.wiretest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'wire-test-ua', id: 'wire-test-device');

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recordedBodies.add(body);
      recordedRequests.add((method: request.method, path: request.uri.path));

      final delay = nextResponseDelay;
      nextResponseDelay = null;
      if (delay != null) {
        await Future<void>.delayed(delay);
      }

      if (respondWithStatus != 200) {
        request.response.statusCode = respondWithStatus;
        request.response.write('{}');
        await request.response.close();
        return;
      }

      if (request.uri.path == '/visit') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'user': {'uid': 'server-uid', 'ses': 'server-ses'},
          'campaigns': <Object>[],
        }));
        await request.response.close();
        return;
      }

      final items = (body['data'] as List).cast<Map<String, dynamic>>();
      // Contract echo: selector items echo it; campaignId items echo the cid
      // inside payload, with no selector.
      final campaigns = nextResponseCampaigns ??
          [
            for (final item in items)
              {
                'selector': item['selector'],
                'payload': [
                  payloadFor(
                    item['selector'] != null ? 'camp-${item['selector']}' : item['campaignId'] as String,
                  ),
                ],
              },
          ];
      nextResponseCampaigns = null;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'user': {'uid': 'server-uid', 'ses': 'server-ses'}, 'data': campaigns}));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'wire-test-key', section: 'wire-test-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    recordedBodies.clear();
    recordedRequests.clear();
    respondWithStatus = 200;
    nextResponseCampaigns = null;
    nextResponseDelay = null;
  });

  tearDown(() async {
    await SessionManager.instance.resetSession();
  });

  test('a single call produces one POST /choose with the unchanged wire shape', () async {
    final response = await choose('single');

    expect(recordedRequests, hasLength(1));
    expect(recordedRequests.single, (method: 'POST', path: '/choose'));
    final body = recordedBodies.single;
    expect(body['sec'], 'wire-test-section');
    expect(body.keys, containsAll(['sec', 'data', 'device', 'user', 'ctx', 'options']));
    expect((body['device'] as Map)['ua'], 'wire-test-ua');
    expect((body['ctx'] as Map)['location'], '/wire');
    final data = body['data'] as List;
    expect(data, hasLength(1));
    final item = data.single as Map;
    expect(item['selector'], 'single');
    expect(item['option'], isA<Map<String, dynamic>>());
    expect(item.containsKey('rules'), isFalse);
    expect(response.data.single.selector, 'single');
  });

  test('two different selectors sharing an envelope merge into ONE POST with a 2-item data array', () async {
    final f1 = choose('merge-1');
    final f2 = choose('merge-2');
    final r1 = await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    final data = recordedBodies.single['data'] as List;
    expect(data.map((e) => (e as Map)['selector']), ['merge-1', 'merge-2']);
    expect(r1.data.single.selector, 'merge-1');
    expect(r2.data.single.selector, 'merge-2');
  });

  test('identical concurrent calls are deduplicated into one POST and share one response', () async {
    final f1 = choose('dup');
    final f2 = choose('dup');
    final r1 = await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    expect(recordedBodies.single['data'] as List, hasLength(1));
    expect(identical(r1, r2), isTrue);
  });

  test('same selector with different contentSettings is NOT deduplicated and NOT merged', () async {
    final f1 = choose('wave');
    final f2 = choose('wave', contentSettings: const ContentSettings(skusOnly: true));
    await Future.wait([f1, f2]);

    // Same envelope but colliding identifiers: the response could not be
    // demuxed from one call, so the group splits into two 1-item POSTs.
    expect(recordedBodies, hasLength(2));
    for (final body in recordedBodies) {
      final data = body['data'] as List;
      expect(data, hasLength(1));
      expect((data.single as Map)['selector'], 'wave');
    }
  });

  test('different users produce separate POSTs (envelope split)', () async {
    final f1 = choose('user-a', customUser: const User(custom: 'alice', ses: 'ses-a'));
    final f2 = choose('user-b', customUser: const User(custom: 'bob', ses: 'ses-b'));
    await Future.wait([f1, f2]);

    expect(recordedBodies, hasLength(2));
    expect(recordedBodies.every((b) => (b['data'] as List).length == 1), isTrue);
  });

  test('a mixed selector+campaignId merge demuxes each caller to its own campaign', () async {
    // The selector campaign resolves to the directly-requested campaignId
    // and arrives later — it must not shadow the direct answer.
    nextResponseCampaigns = [
      {'selector': null, 'payload': [payloadFor('target-cid')]},
      {'selector': 'mix-sel', 'payload': [payloadFor('target-cid')]},
    ];

    final f1 = choose('mix-sel');
    final f2 = GravityRepo.instance.getContentByCampaignId(
      campaignId: 'target-cid',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: const ContentSettings(),
    );
    final r1 = await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    expect(recordedBodies.single['data'] as List, hasLength(2));
    expect(r1.data.single.selector, 'mix-sel');
    expect(r2.data.single.selector, isNull);
  });

  test('a direct campaignId found in a later payload entry still demuxes', () async {
    nextResponseCampaigns = [
      {'selector': 'deep-sel', 'payload': [payloadFor('camp-deep-sel')]},
      {'selector': null, 'payload': [payloadFor('other-cid'), payloadFor('deep-cid')]},
    ];

    final f1 = choose('deep-sel');
    final f2 = GravityRepo.instance.getContentByCampaignId(
      campaignId: 'deep-cid',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: const ContentSettings(),
    );
    final r1 = await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    expect(r1.data.single.selector, 'deep-sel');
    // The requested campaign is the SECOND payload entry.
    expect(r2.data.single.payload.map((p) => p.campaignId), contains('deep-cid'));
  });

  test('colliding identifiers on a cold session adopt the first wave session', () async {
    final f1 = choose('cold');
    final f2 = choose('cold', contentSettings: const ContentSettings(skusOnly: true));
    await Future.wait([f1, f2]);

    expect(recordedBodies, hasLength(2));
    // The second wave must reuse the session opened by the first wave instead
    // of going out anonymously and opening a second server-side session.
    expect((recordedBodies[1]['user'] as Map)['ses'], 'server-ses');
  });

  test('colliding identifiers still merge with other selectors inside each wave', () async {
    final futures = [
      choose('wave-a'),
      choose('wave-a', contentSettings: const ContentSettings(skusOnly: true)),
      choose('wave-b'),
      choose('wave-b', contentSettings: const ContentSettings(skusOnly: true)),
    ];
    final responses = await Future.wait(futures);

    // Wave 0 = first occurrences, wave 1 = second occurrences; waves run
    // sequentially on a cold session, so the body order is deterministic.
    expect(recordedBodies, hasLength(2));
    for (final body in recordedBodies) {
      final data = body['data'] as List;
      expect(data.map((e) => (e as Map)['selector']), ['wave-a', 'wave-b']);
    }
    expect(responses.map((r) => r.data.single.selector), ['wave-a', 'wave-a', 'wave-b', 'wave-b']);
  });

  test('a merged request missing from the response resolves to an empty ContentResponse', () async {
    nextResponseCampaigns = [
      {'selector': 'part-1', 'payload': [payloadFor('camp-part-1')]},
    ];

    final f1 = choose('part-1');
    final f2 = choose('part-2');
    final r1 = await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    expect(recordedBodies.single['data'] as List, hasLength(2));
    expect(r1.data.single.selector, 'part-1');
    expect(r2.data, isEmpty);
  });

  test('a merged POST carries each item\'s own contentSettings and rules', () async {
    final f1 = choose('opt-default');
    final f2 = choose(
      'opt-skus',
      contentSettings: const ContentSettings(skusOnly: true),
      rules: [const RtRule(type: 'include', conditions: [])],
    );
    await Future.wait([f1, f2]);

    expect(recordedBodies, hasLength(1));
    final data = (recordedBodies.single['data'] as List).cast<Map<String, dynamic>>();
    expect(data[0]['selector'], 'opt-default');
    expect((data[0]['option'] as Map)['skusOnly'], false);
    expect(data[0].containsKey('rules'), isFalse);
    expect(data[1]['selector'], 'opt-skus');
    expect((data[1]['option'] as Map)['skusOnly'], true);
    final rules = (data[1]['rules'] as List).cast<Map<String, dynamic>>();
    expect(rules.single['type'], 'include');
  });

  test('a response collapsing a selector and a direct campaignId into one entry resolves both', () async {
    nextResponseCampaigns = [
      {'selector': 'col-sel', 'payload': [payloadFor('col-cid')]},
    ];

    final f1 = choose('col-sel');
    final f2 = GravityRepo.instance.getContentByCampaignId(
      campaignId: 'col-cid',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: const ContentSettings(),
    );
    final r1 = await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    expect(r1.data.single.selector, 'col-sel');
    expect(r2.data.single.payload.single.campaignId, 'col-cid');
  });

  test('an unrequested selector campaign cannot shadow a direct answer sharing its campaignId', () async {
    nextResponseCampaigns = [
      {'selector': 'shadow-sel', 'payload': [payloadFor('camp-shadow-sel')]},
      {'selector': null, 'payload': [payloadFor('shadow-cid', decisionId: 'direct')]},
      {'selector': 'promo-unrequested', 'payload': [payloadFor('shadow-cid', decisionId: 'decorated')]},
    ];

    final f1 = choose('shadow-sel');
    final f2 = GravityRepo.instance.getContentByCampaignId(
      campaignId: 'shadow-cid',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: const ContentSettings(),
    );
    await f1;
    final r2 = await f2;

    expect(r2.data.single.payload.single.decisionId, 'direct');
  });

  test('resetSession inside the batch window is not undone by the flush', () async {
    final future = choose('reset-race');
    // Reset once the request is provably scheduled but the flush not fired.
    while (GravityRepo.instance.debugPendingChooseRequests == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await SessionManager.instance.resetSession();

    final response = await future;

    expect(response.data.single.selector, 'reset-race');
    // The flushed POST echoed a user snapshotted before the reset; adopting
    // it would resurrect the logged-out identity.
    expect(SessionManager.instance.userId, isNull);
    expect(SessionManager.instance.sessionId, isNull);
  });

  test('resetSession between the user snapshot and the flush does not resurrect a warm session', () async {
    await choose('warm-up');
    expect(SessionManager.instance.userId, 'server-uid');

    // choose() runs synchronously up to the await inside _ensureUser, so the
    // old user is already snapshotted when the reset below executes.
    final future = choose('resurrect');
    await SessionManager.instance.resetSession();
    final response = await future;

    expect(response.data.single.selector, 'resurrect');
    expect(SessionManager.instance.userId, isNull);
    expect(SessionManager.instance.sessionId, isNull);
  });

  test('a direct campaignId can be served by an unrequested selector campaign carrying its payload', () async {
    // Parity with the unbatched path, which would return this campaign too.
    nextResponseCampaigns = [
      {'selector': 'lib-sel', 'payload': [payloadFor('camp-lib-sel')]},
      {'selector': 'decorated-unrequested', 'payload': [payloadFor('lib-cid')]},
    ];

    final f1 = choose('lib-sel');
    final f2 = GravityRepo.instance.getContentByCampaignId(
      campaignId: 'lib-cid',
      pageContext: ctx(),
      options: const Options(),
      contentSetting: const ContentSettings(),
    );
    await f1;
    final r2 = await f2;

    expect(recordedBodies, hasLength(1));
    expect(r2.data.single.payload.single.campaignId, 'lib-cid');
  });

  test('identical requests straddling a reset are not deduplicated', () async {
    final f1 = choose('straddle');
    while (GravityRepo.instance.debugPendingChooseRequests == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await SessionManager.instance.resetSession();
    final f2 = choose('straddle');
    await Future.wait([f1, f2]);

    // Different session epochs must not share one response, and the flush
    // must still adopt the post-reset session.
    expect(recordedBodies, hasLength(2));
    expect(SessionManager.instance.sessionId, 'server-ses');
  });

  test('a second envelope group on a cold session parks behind the first', () async {
    final f1 = choose('park-a');
    final f2 = choose(
      'park-b',
      pageContext: const PageContext(type: ContextType.other, data: [], location: '/park-other'),
    );
    await Future.wait([f1, f2]);

    expect(recordedBodies, hasLength(2));
    // Group B must reuse group A's session instead of racing it anonymously.
    expect((recordedBodies[1]['user'] as Map)['ses'], 'server-ses');
  });

  test('a visit parked behind a choose gate re-snapshots after a mid-flight reset', () async {
    nextResponseDelay = const Duration(milliseconds: 300);
    final gateOwner = choose('gate-owner');
    while (recordedRequests.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    // The choose POST is in flight and owns the init gate; this visit parks.
    final parkedVisit = GravityRepo.instance.visit(pageContext: ctx(), options: const Options());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await SessionManager.instance.resetSession();

    await gateOwner;
    await parkedVisit;

    // Woken with stale snapshots, the visit must re-capture generation and
    // user, so its own response is adopted as the fresh session.
    expect(SessionManager.instance.userId, 'server-uid');
    expect(SessionManager.instance.sessionId, 'server-ses');
  });

  test('a gate-owning visit re-snapshots through the reset barrier, not around it', () async {
    // A uid persisted by a previous app run.
    await Prefs.instance.setUserId('relic-uid');

    final visit = GravityRepo.instance.visit(pageContext: ctx(), options: const Options());
    // The gate-owning visit is suspended inside its first user snapshot.
    unawaited(SessionManager.instance.resetSession());
    await visit;

    expect(recordedRequests.single.path, '/visit');
    expect(((recordedBodies.single['user'] ?? const <String, Object>{}) as Map)['uid'], isNull);
  });

  test('a failed merged POST propagates to every caller without unhandled zone errors', () async {
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      respondWithStatus = 500;
      final f1 = choose('fail-1');
      final f2 = choose('fail-2');

      final e1 = expectLater(f1, throwsA(isA<DioException>()));
      final e2 = expectLater(f2, throwsA(isA<DioException>()));
      await Future.wait([e1, e2]);
    }, (error, stackTrace) {
      unhandled.add(error);
    })!;

    // Unhandled future errors surface asynchronously; give them time to fire.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(unhandled, isEmpty);
  });

  test('a failed first visit does not produce an unhandled zone error', () async {
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      respondWithStatus = 500;
      // Fresh session (tearDown resets), so this visit opens the first-request
      // session gate and its failure error-completes the gate completer.
      await expectLater(
        GravityRepo.instance.visit(pageContext: ctx(), options: const Options()),
        throwsA(isA<DioException>()),
      );
    }, (error, stackTrace) {
      unhandled.add(error);
    })!;

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(unhandled, isEmpty);
  });
}
