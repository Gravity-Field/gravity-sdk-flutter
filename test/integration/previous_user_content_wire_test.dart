import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sdk = GravitySDK.instance;
  late HttpServer server;
  late Completer<void> arrived;
  late Completer<void> release;
  late Completer<void> trackingArrived;
  var errorCase = 0;
  String? heldPath;
  var failHeld = false;
  final paths = <String>[];
  final loads = <ContentLoadEvent>[];
  final callbacks = <GravityDataResponse<ContentResponse>>[];
  final originalRetryDelays = Api.retryDelays;
  const context = PageContext(
    type: ContextType.other,
    data: [],
    location: '/previous-user',
  );

  final calls = <({String name, bool details, Future<Object> Function() call})>[
    (
      name: 'getContentBySelector',
      details: false,
      call: () =>
          sdk.getContentBySelector(selector: 'inline', pageContext: context),
    ),
    (
      name: 'getContentByCampaignId',
      details: false,
      call: () =>
          sdk.getContentByCampaignId(campaignId: 'high', pageContext: context),
    ),
    (
      name: 'getContentByGroup',
      details: false,
      call: () => sdk.getContentByGroup(group: 'group', pageContext: context),
    ),
    (
      name: 'getContentBySelectorWithDetails',
      details: true,
      call: () => sdk.getContentBySelectorWithDetails(
        selector: 'inline',
        pageContext: context,
      ),
    ),
    (
      name: 'getContentByCampaignIdWithDetails',
      details: true,
      call: () => sdk.getContentByCampaignIdWithDetails(
        campaignId: 'high',
        pageContext: context,
      ),
    ),
  ];
  final changes = <String, Future<void> Function()>{
    'setUser': () async => sdk.setUser('user-b', 'session-b'),
    'resetUser': sdk.resetUser,
    'restoreUserId': () => sdk.restoreUserId('restored-uid'),
  };
  final noShowCalls =
      <String, Future<GravityDataResponse<ContentResponse>?> Function()>{
        'trackViewNoShow': () => sdk.trackViewNoShow(pageContext: context),
        'triggerEventNoShow': () => sdk.triggerEventNoShow(
          events: [CustomEvent(type: 'custom-v1', name: 'test')],
          pageContext: context,
        ),
      };

  ContentResponse contentOf(Object result) => result is ContentResponse
      ? result
      : (result as GravityDataResponse<ContentResponse>).data;

  Future<void> waitForRequest() =>
      arrived.future.timeout(const Duration(seconds: 5));

  Future<void> flushTracking() async {
    // All tracking calls have been started before the SDK response completes.
    // An awaited request on the same transport lets those calls reach the server.
    await sdk.getContentBySelector(
      selector: 'tracking-barrier',
      pageContext: context,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'previous-user-test',
      packageName: 'ai.gravityfield.previoususer',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(
      userAgent: 'test-ua',
      id: 'test-device',
    );
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    GravityRepo.chooseBatchDelay = Duration.zero;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      paths.add(path);
      if (path == '/loaded' && !trackingArrived.isCompleted) {
        trackingArrived.complete();
      }
      if (request.method == 'GET') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      if (heldPath == path) {
        heldPath = null;
        arrived.complete();
        await release.future;
        if (failHeld) {
          request.response.statusCode = 500;
          request.response.write('{}');
          await request.response.close();
          return;
        }
      }
      final items = (body['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'user': {'uid': 'previous-uid', 'ses': 'previous-ses'},
          if (path != '/choose')
            'campaigns': [
              {
                'campaignId': 'low',
                'priority': 1,
                'trigger': 'view',
                'delayTime': 0,
              },
              {
                'campaignId': 'high',
                'priority': 2,
                'trigger': 'view',
                'delayTime': 0,
              },
            ],
          if (path == '/choose')
            'data': [
              for (final item in items)
                if (item['selector'] != 'tracking-barrier')
                  {
                    'selector': item['selector'],
                    'payload': [
                      {
                        'campaignId': item['campaignId'] ?? 'high',
                        'experienceId': 'exp',
                        'variationId': 'var',
                        'decisionId': 'dec',
                        'contents': [
                          {
                            'contentId': 'previous-content',
                            'contentType': 'native',
                            'deliveryMethod': 'inline',
                            'variables': {
                              'onLoad': {'action': 'load'},
                              'elements': <Object>[],
                            },
                            'events': [
                              {
                                'type': 'load',
                                'urls': [
                                  'http://127.0.0.1:${server.port}/loaded',
                                ],
                              },
                            ],
                          },
                        ],
                      },
                    ],
                  },
            ],
        }),
      );
      await request.response.close();
    });
    await sdk.initialize(apiKey: 'test-key', section: 'test-section');
    sdk.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  setUp(() async {
    await sdk.resetUser();
    sdk.setUser('user-a', 'session-a');
    sdk.gravityEventCallback = (event) {
      if (event is ContentLoadEvent) loads.add(event);
    };
    sdk.gravityContentCallback = callbacks.add;
    paths.clear();
    loads.clear();
    callbacks.clear();
    trackingArrived = Completer<void>();
    arrived = Completer<void>();
    release = Completer<void>();
    heldPath = null;
    failHeld = false;
  });

  tearDown(() async {
    if (!release.isCompleted) release.complete();
    if (loads.isNotEmpty) {
      await trackingArrived.future.timeout(const Duration(seconds: 5));
    }
    sdk.gravityEventCallback = null;
    sdk.gravityContentCallback = null;
  });

  tearDownAll(() async {
    await server.close(force: true);
    Api.retryDelays = originalRetryDelays;
    OutboxDispatcher.lifecycleObserverEnabled = true;
  });

  for (final call in calls) {
    group(call.name, () {
      for (final change in changes.entries) {
        test(
          'discards content and notifications after ${change.key}',
          () async {
            heldPath = '/choose';
            final pending = call.call();
            await waitForRequest();
            await change.value();
            release.complete();
            final result = await pending;
            await flushTracking();

            expect(loads, isEmpty);
            expect(callbacks, isEmpty);
            expect(paths.where((path) => path == '/loaded'), isEmpty);
            expect(contentOf(result).data, isEmpty);
            if (call.details) {
              final json =
                  (result as GravityDataResponse<ContentResponse>).json;
              expect(
                json['data'],
                isEmpty,
                reason: 'raw JSON must not expose previous content either',
              );
            }
          },
        );
      }

      test(
        'returns content and notifications when identity is unchanged',
        () async {
          heldPath = '/choose';
          final pending = call.call();
          await waitForRequest();
          sdk.setUser('user-a', 'session-a');
          release.complete();
          final result = await pending;
          await flushTracking();

          expect(
            contentOf(
              result,
            ).data.single.payload.single.contents.single.contentId,
            'previous-content',
          );
          expect(loads, hasLength(1));
          expect(callbacks, hasLength(call.details ? 1 : 0));
          expect(paths.where((path) => path == '/loaded'), hasLength(1));
        },
      );

      if (call.details) {
        test('empty stale JSON can be extended by the app', () async {
          heldPath = '/choose';
          final pending = call.call();
          await waitForRequest();
          await sdk.resetUser();
          release.complete();
          final result = await pending as GravityDataResponse<ContentResponse>;
          result.json['renderContext'] = 'app';
          (result.json['user'] as Map<String, dynamic>)['marker'] = 'app';
          (result.json['data'] as List).add('app');
          expect(result.json['renderContext'], 'app');
          expect(result.json['user'], {'marker': 'app'});
          expect(result.json['data'], ['app']);
        });
      }

      test('still throws HTTP errors after an identity change', () async {
        heldPath = '/choose';
        failHeld = true;
        final pending = call.call();
        final assertion = expectLater(pending, throwsA(isA<DioException>()));
        await waitForRequest();
        await sdk.restoreUserId('restored-uid');
        release.complete();
        await assertion;
        expect(loads, isEmpty);
        expect(callbacks, isEmpty);
      });
    });
  }

  for (final call in noShowCalls.entries) {
    for (final phase in ['tracking', 'choose']) {
      for (final change in changes.entries) {
        test(
          '${call.key} returns null after ${change.key} during $phase',
          () async {
            heldPath = phase == 'choose'
                ? '/choose'
                : (call.key == 'trackViewNoShow' ? '/visit' : '/event');
            final pending = call.value();
            await waitForRequest();
            await change.value();
            release.complete();
            final result = await pending;
            await flushTracking();

            expect(loads, isEmpty);
            expect(callbacks, isEmpty);
            expect(result, isNull);
            expect(
              paths.where((path) => path == '/choose'),
              hasLength(phase == 'choose' ? 2 : 1),
              reason:
                  'only the held choose and tracking barrier are allowed; no obsolete priority fallback',
            );
            expect(paths.where((path) => path == '/loaded'), isEmpty);
          },
        );
      }
    }
    test(
      '${call.key} stops priority fallback after a stale choose failure',
      () async {
        // Each case gets a fresh reporting window, so rate limiting cannot
        // make the absence of the resolver report a false positive.
        final originalNow = Clock.now;
        var now = DateTime.now().add(Duration(minutes: 10 * ++errorCase));
        Clock.now = () => now;
        addTearDown(() => Clock.now = originalNow);
        final reportedSections = <String>[];
        ErrorReporter.observer = (section, _) {
          reportedSections.add(section);
          if (section == 'GravityRepo.getContentByCampaignIdWithDetails') {
            // The resolver receives the same exception and stack trace. Move
            // past deduplication too, so a redundant stale report is observable.
            now = now.add(const Duration(minutes: 2));
          }
        };
        addTearDown(() => ErrorReporter.observer = null);
        heldPath = '/choose';
        failHeld = true;
        final pending = call.value();
        await waitForRequest();
        sdk.setUser('user-b', 'session-b');
        release.complete();
        final result = await pending;
        // Cold-start reports resolve identity before notifying the observer.
        await Future<void>.delayed(Duration.zero);
        expect(result, isNull);
        expect(paths.where((path) => path == '/choose'), hasLength(1));
        expect(loads, isEmpty);
        expect(callbacks, isEmpty);
        expect(
          reportedSections,
          contains('GravityRepo.getContentByCampaignIdWithDetails'),
        );
        expect(
          reportedSections,
          isNot(contains('GravitySDK._resolveHighestPriorityNoShow')),
        );
      },
    );
    test('${call.key} returns current content and notifies once', () async {
      final result = await call.value();
      expect(result?.data.data.single.payload.single.campaignId, 'high');
      expect(loads, hasLength(1));
      expect(callbacks, hasLength(1));
    });
  }
}
