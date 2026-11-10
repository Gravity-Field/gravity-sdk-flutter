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
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marker for a campaign whose `delayTime` key is absent from the tracking
/// response.
const _absent = Object();

void main() {
  final sdk = GravitySDK.instance;
  late HttpServer server;
  final originalRetryDelays = Api.retryDelays;
  final originalBatchDelay = GravityRepo.chooseBatchDelay;
  // Campaign id -> delayTime value sent in the tracking response.
  var delays = <String, Object?>{};
  // How the high-priority campaign answers /choose: root, empty or error.
  var highContent = 'root';
  final requests = <String>[];
  final chosen = <String>[];
  final chooseBodies = <String, Map<String, dynamic>>{};
  final callbacks = <GravityDataResponse<ContentResponse>>[];
  final delivered = <String, Completer<void>>{};
  const context = PageContext(
    type: ContextType.other,
    data: [],
    location: '/noshow-delay',
  );
  final calls =
      <String, Future<GravityDataResponse<ContentResponse>?> Function()>{
        'trackViewNoShow': () => sdk.trackViewNoShow(pageContext: context),
        'triggerEventNoShow': () => sdk.triggerEventNoShow(
          events: [CustomEvent(type: 'custom-v1', name: 'test')],
          pageContext: context,
        ),
      };

  Map<String, dynamic> campaign(String id, int priority) => {
    'campaignId': id,
    'priority': priority,
    'trigger': 'view',
    if (!identical(delays[id], _absent)) 'delayTime': delays[id],
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'noshow-delay-test',
      packageName: 'ai.gravityfield.noshowdelay',
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
      requests.add('${request.method} $path');
      if (request.method == 'GET') {
        final id = path.split('/').last;
        delivered.putIfAbsent(id, Completer<void>.new).complete();
        await request.response.close();
        return;
      }
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      if (path != '/choose') {
        request.response.write(
          jsonEncode({
            'user': {'uid': 'uid', 'ses': 'ses'},
            'campaigns': [campaign('low', 1), campaign('high', 2)],
          }),
        );
      } else {
        final items = (body['data'] as List).cast<Map<String, dynamic>>();
        final id = items.single['campaignId'] as String;
        chosen.add(id);
        if (id == 'high' && highContent == 'error') {
          request.response.statusCode = 500;
          request.response.write('{}');
        } else {
          final response = {
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
                      if (id != 'high' || highContent != 'empty')
                        {
                          'contentId': id,
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
          };
          chooseBodies[id] = response;
          request.response.write(jsonEncode(response));
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
    sdk.setOptions(
      isFetchContentOnTrack: true,
      options: const Options(),
      staleContentTimeout: const Duration(seconds: 10),
    );
    delays = {'low': 0, 'high': 0};
    highContent = 'root';
    requests.clear();
    chosen.clear();
    chooseBodies.clear();
    callbacks.clear();
    delivered.clear();
    sdk.gravityContentCallback = callbacks.add;
  });

  Future<void> waitForLoadUrl(String id) => delivered
      .putIfAbsent(id, Completer<void>.new)
      .future
      .timeout(const Duration(seconds: 5));

  tearDown(() async {
    for (final id in chosen.toSet()) {
      if (chooseBodies.containsKey(id) &&
          (id != 'high' || highContent == 'root')) {
        await waitForLoadUrl(id);
      }
    }
    sdk.gravityContentCallback = null;
  });

  tearDownAll(() async {
    await server.close(force: true);
    Api.retryDelays = originalRetryDelays;
    GravityRepo.chooseBatchDelay = originalBatchDelay;
    OutboxDispatcher.lifecycleObserverEnabled = true;
  });

  String campaignOf(GravityDataResponse<ContentResponse>? result) =>
      result!.data.data.single.payload.single.campaignId;

  for (final call in calls.entries) {
    group('${call.key} delayTime', () {
      test('returns a set campaign delay losslessly', () async {
        delays = {'low': 0, 'high': 1500};
        final result = await call.value();
        expect(campaignOf(result), 'high');
        expect(result!.delayTime, 1500);
        expect(chosen, ['high']);
      });

      test(
        'numeric string delay returns the campaign instead of null',
        () async {
          delays = {'low': 0, 'high': ' 1500.0 '};
          final result = await call.value();
          expect(campaignOf(result), 'high');
          expect(result!.delayTime, 1500);
          expect(chosen, ['high']);
        },
      );

      test('missing delay is returned as 0', () async {
        delays = {'low': _absent, 'high': _absent};
        final result = await call.value();
        expect(campaignOf(result), 'high');
        expect(result!.delayTime, 0);
      });

      test('zero delay is returned as 0', () async {
        delays = {'low': 700, 'high': 0};
        final result = await call.value();
        expect(campaignOf(result), 'high');
        expect(result!.delayTime, 0);
      });

      test('negative delay is clamped to 0', () async {
        delays = {'low': 0, 'high': -250};
        final result = await call.value();
        expect(campaignOf(result), 'high');
        expect(result!.delayTime, 0);
      });

      for (final candidate in ['empty', 'error']) {
        test(
          'fallback after $candidate higher-priority campaign returns the '
          'chosen campaign delay',
          () async {
            highContent = candidate;
            delays = {'low': 2500, 'high': 1500};
            final result = await call.value();
            expect(campaignOf(result), 'low');
            expect(result!.delayTime, 2500);
            expect(chosen, ['high', 'low']);
            expect(callbacks.single.delayTime, 2500);
          },
        );
      }

      test(
        'callback receives the same response, delay and json as returned',
        () async {
          delays = {'low': 0, 'high': 1500};
          final result = await call.value();
          expect(callbacks, [same(result)]);
          expect(callbacks.single.delayTime, 1500);
          expect(callbacks.single.json, same(result!.json));
        },
      );

      test('json stays the raw /choose body', () async {
        delays = {'low': 0, 'high': 1500};
        final result = await call.value();
        expect(result!.json, chooseBodies['high']);
        expect(result.json.containsKey('campaigns'), isFalse);
        expect(jsonEncode(result.json), isNot(contains('delayTime')));
      });

      test('returns without waiting the delay', () async {
        delays = {'low': 0, 'high': 60000};
        final stopwatch = Stopwatch()..start();
        final result = await call.value();
        stopwatch.stop();
        expect(result!.delayTime, 60000);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      });

      test('zero delay does not auto-show', () async {
        delays = {'low': 0, 'high': 0};
        final result = await call.value();
        expect(result!.delayTime, 0);
        await waitForLoadUrl('high');
        // A zero-delay auto-show has no campaign timer to hide behind. Drain
        // the event queue after delivery without a real-time sleep.
        await Future<void>(() {});
        expect(chosen, ['high']);
        expect(requests.where((r) => r.startsWith('POST')), hasLength(2));
        expect(requests.where((r) => r == 'POST /choose'), hasLength(1));
        expect(requests.where((r) => r.startsWith('GET')), [
          'GET /loaded/high',
        ]);
        expect(callbacks, [same(result)]);
      });
    });
  }

  test('getContentByCampaignIdWithDetails keeps delayTime 0', () async {
    delays = {'low': 0, 'high': 1500};
    final result = await sdk.getContentByCampaignIdWithDetails(
      campaignId: 'high',
      pageContext: context,
    );
    expect(result.delayTime, 0);
    expect(callbacks.single.delayTime, 0);
  });
}
