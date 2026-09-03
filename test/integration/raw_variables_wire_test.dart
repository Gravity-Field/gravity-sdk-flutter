import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wire-level tests for the raw `variables` object: a real HTTP server answers
/// POST /choose with campaign-defined keys that have no typed counterpart in
/// [Variables], and the public API must hand them back untouched.
void main() {
  late HttpServer server;
  final recordedBodies = <Map<String, dynamic>>[];
  final recordedRequests = <({String method, String path})>[];

  /// Arbitrary, campaign-authored `variables` — the SDK models none of these
  /// keys except `title`.
  Map<String, dynamic> variablesFor(String selector) => switch (selector) {
    'inline_banner' => <String, dynamic>{
      'inline_banner': {'variant': 'B', 'discount': 15},
      'title': 't',
      'flag': true,
    },
    'batch_a' => <String, dynamic>{
      'batch_a': {'variant': 'A', 'slots': ['a1', 'a2']},
      'title': 'title-a',
    },
    'batch_b' => <String, dynamic>{
      'batch_b': {'variant': 'B', 'slots': ['b1']},
      'title': 'title-b',
      'extra': 42,
    },
    _ => <String, dynamic>{'title': 'title-$selector'},
  };

  // No `events` and no onLoad/onImpression action: nothing here makes the SDK
  // fire engagement GETs, so every recorded request is a /choose.
  Map<String, dynamic> campaignFor(String selector) => <String, dynamic>{
    'selector': selector,
    'payload': [
      {
        'campaignId': 'camp-$selector',
        'experienceId': 'exp',
        'variationId': 'var',
        'decisionId': 'dec-$selector',
        'contents': [
          {
            'contentId': 'content-$selector',
            'deliveryMethod': 'inline',
            'contentType': 'json',
            'variables': variablesFor(selector),
          },
        ],
      },
    ],
  };

  PageContext ctx() => const PageContext(type: ContextType.other, data: [], location: '/raw-vars');

  setUpAll(() async {
    // Must run before the first getContent* call: the delay is baked into the
    // late-final batcher. A wide window keeps concurrent test calls merged.
    GravityRepo.chooseBatchDelay = const Duration(milliseconds: 80);
    // An unexpected SDK failure must not reach the real error endpoint.
    ErrorReporter.disableNetworkForTests = true;

    PackageInfo.setMockInitialValues(
      appName: 'raw-vars-test',
      packageName: 'ai.gravityfield.rawvarstest',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({});
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'raw-vars-ua', id: 'raw-vars-device');

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      recordedBodies.add(body);
      recordedRequests.add((method: request.method, path: request.uri.path));

      final items = (body['data'] as List).cast<Map<String, dynamic>>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'user': {'uid': 'server-uid', 'ses': 'server-ses'},
        'data': [for (final item in items) campaignFor(item['selector'] as String)],
      }));
      await request.response.close();
    });

    await GravitySDK.instance.initialize(apiKey: 'raw-vars-key', section: 'raw-vars-section');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    recordedBodies.clear();
    recordedRequests.clear();
  });

  tearDown(() async {
    await SessionManager.instance.resetSession();
  });

  test('getContentBySelectorWithDetails exposes the wire variables verbatim', () async {
    final response = await GravitySDK.instance.getContentBySelectorWithDetails(
      selector: 'inline_banner',
      pageContext: ctx(),
    );

    expect(recordedRequests, hasLength(1));
    expect(recordedRequests.single, (method: 'POST', path: '/choose'));

    final content = response.data.data.single.payload.single.contents.single;

    // The raw map must match the very object sitting in the untouched JSON.
    final jsonCampaign = (response.json['data'] as List).single as Map<String, dynamic>;
    final jsonVariation = (jsonCampaign['payload'] as List).single as Map<String, dynamic>;
    final jsonContent = (jsonVariation['contents'] as List).single as Map<String, dynamic>;
    final jsonVariables = jsonContent['variables'] as Map<String, dynamic>;

    expect(
      const DeepCollectionEquality().equals(content.rawVariables, jsonVariables),
      isTrue,
    );
    // ...and the literal the server actually put on the wire.
    expect(
      const DeepCollectionEquality().equals(content.rawVariables, variablesFor('inline_banner')),
      isTrue,
    );

    // Documented aliasing: nested objects are the very ones inside `json`.
    expect(
      identical(content.rawVariables['inline_banner'], jsonVariables['inline_banner']),
      isTrue,
    );

    final banner = content.variables['inline_banner'];
    expect(banner, isA<Map<String, dynamic>>());
    expect((banner! as Map)['variant'], 'B');
    expect(
      content.variables.valueOf<Map<String, dynamic>>('inline_banner')?['discount'],
      15,
    );
    expect(content.variables.valueOf<bool>('flag'), isTrue);
    // Typed parsing of the same object is unaffected.
    expect(content.variables.title, 't');
    expect(content.deliveryMethod, DeliveryMethod.inline);
  });

  test('WithDetails calls bypass the batcher: two concurrent selectors are two POSTs', () async {
    final f1 = GravitySDK.instance.getContentBySelectorWithDetails(
      selector: 'batch_a',
      pageContext: ctx(),
    );
    final f2 = GravitySDK.instance.getContentBySelectorWithDetails(
      selector: 'batch_b',
      pageContext: ctx(),
    );
    await Future.wait([f1, f2]);

    // GravityRepo.getContentBySelectorWithDetails calls Api directly instead
    // of scheduling on _chooseBatcher, so nothing merges.
    expect(recordedBodies, hasLength(2));
    for (final body in recordedBodies) {
      expect(body['data'] as List, hasLength(1));
    }
    expect(GravityRepo.instance.debugPendingChooseRequests, 0);
  });

  test('a merged batch keeps each selector\'s own raw variables', () async {
    final f1 = GravitySDK.instance.getContentBySelector(selector: 'batch_a', pageContext: ctx());
    final f2 = GravitySDK.instance.getContentBySelector(selector: 'batch_b', pageContext: ctx());
    final r1 = await f1;
    final r2 = await f2;

    // One POST carrying both selectors: the batched path, not two calls.
    expect(recordedBodies, hasLength(1));
    final sent = (recordedBodies.single['data'] as List).cast<Map<String, dynamic>>();
    expect(sent.map((e) => e['selector']), ['batch_a', 'batch_b']);

    final contentA = r1.data.single.payload.single.contents.single;
    final contentB = r2.data.single.payload.single.contents.single;

    expect(r1.data.single.selector, 'batch_a');
    expect(r2.data.single.selector, 'batch_b');

    // Demuxing must not cross the raw payloads over.
    expect(
      const DeepCollectionEquality().equals(contentA.rawVariables, variablesFor('batch_a')),
      isTrue,
    );
    expect(
      const DeepCollectionEquality().equals(contentB.rawVariables, variablesFor('batch_b')),
      isTrue,
    );
    expect(contentA.rawVariables.containsKey('batch_b'), isFalse);
    expect(contentB.rawVariables.containsKey('batch_a'), isFalse);
    expect(contentA.variables.valueOf<Map<String, dynamic>>('batch_a')?['slots'], ['a1', 'a2']);
    expect(contentB.variables.valueOf<Map<String, dynamic>>('batch_b')?['slots'], ['b1']);
    expect(contentB.variables.valueOf<int>('extra'), 42);
    expect(contentA.variables.title, 'title-a');
    expect(contentB.variables.title, 'title-b');
  });
}
