import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
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
  final originalNow = Clock.now;
  final originalRetryDelays = Api.retryDelays;
  final originalBatchDelay = GravityRepo.chooseBatchDelay;
  late DateTime now;
  var testDay = 0;
  var firstContent = 'root';
  List<Map<String, dynamic>>? trackingCampaigns;
  final emptyCampaigns = <String>{};
  var trackingAge = Duration.zero;
  var chooseAge = Duration.zero;
  Duration? timeoutOnChoose;
  final requestOptions = <Map<String, dynamic>>[];
  final chosen = <String>[];
  final loads = <ContentLoadEvent>[];
  final callbacks = <GravityDataResponse<ContentResponse>>[];
  final loadedUrls = <String>[];
  final delivered = <String, Completer<void>>{};
  const context = PageContext(
    type: ContextType.other,
    data: [],
    location: '/noshow-parity',
  );
  final calls =
      <String, Future<GravityDataResponse<ContentResponse>?> Function()>{
        'trackViewNoShow': () => sdk.trackViewNoShow(pageContext: context),
        'triggerEventNoShow': () => sdk.triggerEventNoShow(
          events: [CustomEvent(type: 'custom-v1', name: 'test')],
          pageContext: context,
        ),
      };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'noshow-test',
      packageName: 'ai.gravityfield.noshow',
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
      if (request.method == 'GET') {
        final id = path.split('/').last;
        loadedUrls.add(id);
        delivered.putIfAbsent(id, Completer<void>.new).complete();
        await request.response.close();
        return;
      }
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      requestOptions.add((body['options'] as Map).cast<String, dynamic>());
      request.response.headers.contentType = ContentType.json;
      if (path != '/choose') {
        now = now.add(trackingAge);
        request.response.write(
          jsonEncode({
            'user': {'uid': 'uid', 'ses': 'ses'},
            'campaigns':
                trackingCampaigns ??
                [
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
          }),
        );
      } else {
        final items = (body['data'] as List).cast<Map<String, dynamic>>();
        final id = items.single['campaignId'] as String;
        chosen.add(id);
        if (timeoutOnChoose != null) {
          sdk.setOptions(staleContentTimeout: timeoutOnChoose);
        }
        if (id == 'high') now = now.add(chooseAge);
        if (id == 'high' && firstContent == 'error') {
          request.response.statusCode = 500;
          request.response.write('{}');
        } else {
          request.response.write(
            jsonEncode({
              'user': {'uid': 'uid', 'ses': 'ses'},
              'data': [
                {
                  'payload': [
                    {
                      'campaignId': id,
                      'experienceId': 'exp',
                      'variationId': 'var',
                      'decisionId': 'dec',
                      'contents': [
                        if (!emptyCampaigns.contains(id) &&
                            (id != 'high' || firstContent != 'empty'))
                          {
                            'contentId': id,
                            'contentType': 'native',
                            'deliveryMethod': 'inline',
                            if ((id == 'high' && firstContent == 'step') ||
                                firstContent == 'stepsOnly')
                              'step': 1,
                            'variables': {
                              'onLoad': {'action': 'load'},
                              'elements': <Object>[],
                            },
                            'events': [
                              {
                                'type': 'load',
                                'urls': [
                                  'http://127.0.0.1:${server.port}/loaded/$id',
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
        }
      }
      await request.response.close();
    });
    await sdk.initialize(apiKey: 'test-key', section: 'test-section');
    sdk.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  setUp(() async {
    await sdk.resetUser();
    sdk.setUser('custom-user', 'custom-session');
    now = DateTime.utc(2026, 1, ++testDay);
    Clock.now = () => now;
    sdk.setOptions(staleContentTimeout: const Duration(seconds: 10));
    firstContent = 'root';
    trackingCampaigns = null;
    emptyCampaigns.clear();
    trackingAge = Duration.zero;
    chooseAge = Duration.zero;
    timeoutOnChoose = null;
    requestOptions.clear();
    sdk.setOptions(isFetchContentOnTrack: true, options: const Options());
    chosen.clear();
    loads.clear();
    callbacks.clear();
    loadedUrls.clear();
    delivered.clear();
    sdk.gravityEventCallback = (event) {
      if (event is ContentLoadEvent) loads.add(event);
    };
    sdk.gravityContentCallback = callbacks.add;
  });

  Future<void> waitForLoadUrls() async {
    for (final load in loads) {
      await delivered
          .putIfAbsent(load.content.contentId, Completer<void>.new)
          .future
          .timeout(const Duration(seconds: 5));
    }
  }

  tearDown(() async {
    await waitForLoadUrls();
    sdk.gravityEventCallback = null;
    sdk.gravityContentCallback = null;
    ErrorReporter.observer = null;
    Clock.now = originalNow;
  });

  tearDownAll(() async {
    await server.close(force: true);
    Api.retryDelays = originalRetryDelays;
    GravityRepo.chooseBatchDelay = originalBatchDelay;
    OutboxDispatcher.lifecycleObserverEnabled = true;
  });

  for (final call in calls.entries) {
    group(call.key, () {
      for (final scenario in [
        (name: '40 equal priorities', high: 0, empty: <String>[], tried: ['0']),
        (
          name: '40 equal priorities with fallback',
          high: 0,
          empty: ['0'],
          tried: ['0', '1'],
        ),
        (
          name: '40 campaigns with a lower-priority tie',
          high: 3,
          empty: ['0', '1', '2'],
          tried: ['0', '1', '2', '3'],
        ),
      ]) {
        test('keeps server order for ${scenario.name}', () async {
          trackingCampaigns = [
            for (var i = 0; i < 40; i++)
              {
                'campaignId': '$i',
                'priority': i < scenario.high ? 5 : 1,
                'trigger': 'view',
                'delayTime': 0,
              },
          ];
          emptyCampaigns.addAll(scenario.empty);
          final result = await call.value();
          await waitForLoadUrls();
          expect(chosen, scenario.tried);
          expect(
            result?.data.data.single.payload.single.campaignId,
            scenario.tried.last,
          );
          expect(loads.map((event) => event.content.contentId), [
            scenario.tried.last,
          ]);
          expect(loadedUrls, [scenario.tried.last]);
          expect(callbacks, [same(result)]);
        });
      }

      for (final elapsed in [Duration.zero, const Duration(microseconds: 1)]) {
        test(
          'negative timeout permits only instantaneous content ($elapsed)',
          () async {
            sdk.setOptions(staleContentTimeout: const Duration(seconds: -5));
            trackingAge = elapsed;
            expect(
              await call.value(),
              elapsed == Duration.zero ? isNotNull : isNull,
            );
            expect(chosen, elapsed == Duration.zero ? ['high'] : isEmpty);
          },
        );
      }

      for (final implicit in [false, true]) {
        test(
          'passes host implicit-impression option $implicit through tracking and choose',
          () async {
            sdk.setOptions(options: Options(isImplicitImpression: implicit));
            sdk.lockPresentation();
            try {
              expect(await call.value(), isNotNull);
              expect(chosen, ['high']);
              expect(
                requestOptions.map(
                  (options) => options['isImplicitImpression'],
                ),
                [implicit, implicit],
              );
            } finally {
              sdk.unlockPresentation();
            }
          },
        );
      }

      test('fetch disabled still tracks without choosing content', () async {
        sdk.setOptions(isFetchContentOnTrack: false);
        expect(await call.value(), isNull);
        expect(requestOptions, hasLength(1));
        expect(chosen, isEmpty);
      });

      for (final extend in [false, true]) {
        test(
          'uses the current timeout after choose when it is ${extend ? 'extended' : 'shortened'}',
          () async {
            sdk.setOptions(
              staleContentTimeout: Duration(seconds: extend ? 10 : 20),
            );
            timeoutOnChoose = Duration(seconds: extend ? 20 : 10);
            chooseAge = const Duration(seconds: 11);
            expect(await call.value(), extend ? isNotNull : isNull);
            expect(chosen, ['high']);
          },
        );
      }

      test(
        'rejects root content when tracking plus choose exceed timeout',
        () async {
          trackingAge = const Duration(seconds: 6);
          chooseAge = const Duration(seconds: 5);
          expect(await call.value(), isNull);
          expect(chosen, ['high']);
        },
      );

      for (final candidate in ['step', 'empty', 'error']) {
        test(
          'stops after a stale $candidate choose without fallback',
          () async {
            firstContent = candidate;
            chooseAge = const Duration(seconds: 11);
            expect(await call.value(), isNull);
            expect(chosen, ['high']);
          },
        );
      }

      test(
        'checks timeout again before the next choose after error reporting',
        () async {
          // Keep this observer-driven timing probe synchronous. Cold-start
          // reports now resolve identity asynchronously before notifying it.
          await SessionManager.instance.restoreUserId('report-device');
          firstContent = 'error';
          sdk.setOptions(staleContentTimeout: const Duration(minutes: 5));
          var resolverReported = false;
          // A failure may consume the remaining time while it is reported.
          ErrorReporter.observer = (section, _) {
            if (section == 'GravityRepo.getContentByCampaignIdWithDetails') {
              // Let the resolver's duplicate report through without expiring
              // the operation yet.
              now = now.add(const Duration(minutes: 2));
            }
            if (section == 'GravitySDK._resolveHighestPriorityNoShow') {
              resolverReported = true;
              now = now.add(const Duration(minutes: 6));
            }
          };
          expect(await call.value(), isNull);
          expect(resolverReported, isTrue);
          expect(chosen, ['high']);
        },
      );

      test('accepts content at the exact timeout boundary', () async {
        chooseAge = const Duration(seconds: 10);
        final result = await call.value();
        expect(result?.data.data.single.payload.single.campaignId, 'high');
        expect(chosen, ['high']);
      });

      test(
        'notifies only the accepted response after a step-only candidate',
        () async {
          firstContent = 'step';
          final result = await call.value();
          await waitForLoadUrls();
          expect(result?.data.data.single.payload.single.campaignId, 'low');
          expect(chosen, ['high', 'low']);
          expect(loads.map((event) => event.content.contentId), ['low']);
          expect(callbacks, [same(result)]);
          expect(loadedUrls, ['low']);
        },
      );

      test(
        'returns null without notifications when every candidate is step-only',
        () async {
          firstContent = 'stepsOnly';
          expect(await call.value(), isNull);
          await waitForLoadUrls();
          expect(chosen, ['high', 'low']);
          expect(loads, isEmpty);
          expect(callbacks, isEmpty);
          expect(loadedUrls, isEmpty);
        },
      );

      test('does not notify for an empty candidate', () async {
        firstContent = 'empty';
        final result = await call.value();
        await waitForLoadUrls();
        expect(result?.data.data.single.payload.single.campaignId, 'low');
        expect(chosen, ['high', 'low']);
        expect(loads.map((event) => event.content.contentId), ['low']);
        expect(callbacks, [same(result)]);
        expect(loadedUrls, ['low']);
      });

      test('does not notify when the choose response has expired', () async {
        chooseAge = const Duration(seconds: 11);
        expect(await call.value(), isNull);
        await waitForLoadUrls();
        expect(loads, isEmpty);
        expect(callbacks, isEmpty);
        expect(loadedUrls, isEmpty);
      });

      test('keeps error fallback and accepted onLoad tracking', () async {
        firstContent = 'error';
        final result = await call.value();
        await waitForLoadUrls();
        expect(result?.data.data.single.payload.single.campaignId, 'low');
        expect(chosen, ['high', 'low']);
        expect(loads.map((event) => event.content.contentId), ['low']);
        expect(callbacks, [same(result)]);
        expect(loadedUrls, ['low']);
      });
    });
  }

  test('public detailed getter still notifies for step-only content', () async {
    firstContent = 'step';
    final result = await sdk.getContentByCampaignIdWithDetails(
      campaignId: 'high',
      pageContext: context,
    );
    await waitForLoadUrls();
    expect(result.data.data.single.payload.single.contents.single.step, 1);
    expect(loads.map((event) => event.content.contentId), ['high']);
    expect(callbacks, [same(result)]);
    expect(loadedUrls, ['high']);
  });
}
