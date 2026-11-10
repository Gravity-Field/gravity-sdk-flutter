import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final originalNow = Clock.now;
  final originalRetryDelays = Api.retryDelays;
  final originalBatchDelay = GravityRepo.chooseBatchDelay;
  late DateTime now;
  var testDay = 0;
  var firstContent = 'root';
  var flipAt = 'none';
  final chosen = <String>[];
  final tracked = <String>[];
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
      request.response.headers.contentType = ContentType.json;
      if (path != '/choose') {
        tracked.add(path);
        if (flipAt == 'tracking') sdk.isFetchContentOnTrack = false;
        request.response.write(
          jsonEncode({
            'user': {'uid': 'uid', 'ses': 'ses'},
            'campaigns': [
              {
                'campaignId': 'low',
                'priority': 1,
                'trigger': 'view',
                'delayTime': 0,
              },
              {
                'campaignId': 'middle',
                'priority': 2,
                'trigger': 'view',
                'delayTime': 0,
              },
              {
                'campaignId': 'high',
                'priority': 3,
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
        if (chosen.length == 1 && flipAt == 'choose') {
          sdk.isFetchContentOnTrack = false;
        }
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
    flipAt = 'none';
    sdk.setOptions(isFetchContentOnTrack: true, options: const Options());
    chosen.clear();
    tracked.clear();
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
      for (final stage in ['before', 'tracking']) {
        test(
          'fetch disabled ${stage == 'before' ? 'before call' : 'during tracking'} skips all choose requests',
          () async {
            flipAt = stage;
            if (stage == 'before') sdk.isFetchContentOnTrack = false;
            final result = await call.value();
            await waitForLoadUrls();
            expect(tracked, [
              call.key == 'trackViewNoShow' ? '/visit' : '/event',
            ]);
            expect(chosen, isEmpty);
            expect(result, isNull);
            expect(loads, isEmpty);
            expect(callbacks, isEmpty);
            expect(loadedUrls, isEmpty);
          },
        );
      }

      for (final candidate in ['step', 'error', 'root']) {
        test(
          'fetch disabled during first $candidate choose cancels content',
          () async {
            firstContent = candidate;
            flipAt = 'choose';
            final reportedSections = <String>{};
            final repoReported = Completer<void>();
            if (candidate == 'error') {
              ErrorReporter.observer = (section, _) {
                reportedSections.add(section);
                if (section ==
                        'GravityRepo.getContentByCampaignIdWithDetails' &&
                    !repoReported.isCompleted) {
                  repoReported.complete();
                }
              };
            }
            final result = await call.value();
            await waitForLoadUrls();
            if (candidate == 'error') {
              // Repository diagnostics can await identity resolution.
              await repoReported.future.timeout(const Duration(seconds: 5));
              expect(reportedSections, {
                'Api.http://127.0.0.1:${server.port}/choose',
                'GravityRepo.getContentByCampaignIdWithDetails',
              });
            }
            expect(chosen, ['high']);
            expect(result, isNull);
            expect(loads, isEmpty);
            expect(callbacks, isEmpty);
            expect(loadedUrls, isEmpty);
          },
        );
      }

      for (final candidate in ['step', 'error', 'root', 'stepsOnly']) {
        test(
          'fetch enabled preserves $candidate resolution and notifications',
          () async {
            firstContent = candidate;
            final result = await call.value();
            await waitForLoadUrls();
            if (candidate == 'stepsOnly') {
              expect(chosen, ['high', 'middle', 'low']);
              expect(result, isNull);
              expect(loads, isEmpty);
              expect(callbacks, isEmpty);
              expect(loadedUrls, isEmpty);
            } else {
              final accepted = candidate == 'root' ? 'high' : 'middle';
              expect(
                chosen,
                candidate == 'root' ? ['high'] : ['high', 'middle'],
              );
              expect(
                result?.data.data.single.payload.single.campaignId,
                accepted,
              );
              expect(loads.map((event) => event.content.contentId), [accepted]);
              expect(callbacks, [same(result)]);
              expect(loadedUrls, [accepted]);
            }
          },
        );
      }
    });
  }
}
