import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/modal/modal_content.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  final recorded = <({String path, Map<String, dynamic> body})>[];
  final loads = <ContentLoadEvent>[];
  Completer<void>? arrived;
  Completer<void>? release;
  var holdFirstChoose = false;
  final originalRetryDelays = Api.retryDelays;
  final changes = <String, Future<void> Function()>{
    'setUser': () async => GravitySDK.instance.setUser('user-b', 'ses-b'),
    'resetUser': GravitySDK.instance.resetUser,
    'restoreUserId': () => GravitySDK.instance.restoreUserId('restored-uid'),
  };

  const ctx = PageContext(
    type: ContextType.other,
    data: [],
    location: '/probe',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'autoshow-stale-test',
      packageName: 'ai.gravityfield.autoshowstale',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    DeviceUtils.instance.debugDevice = const Device(userAgent: 'ua', id: 'dev');
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    GravityRepo.chooseBatchDelay = Duration.zero;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.method == 'GET') {
        recorded.add((path: request.uri.path, body: const {}));
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      recorded.add((path: request.uri.path, body: body));
      final isChoose = request.uri.path == '/choose';
      if (isChoose && holdFirstChoose) {
        holdFirstChoose = false;
        arrived!.complete();
        await release!.future;
      }
      request.response.headers.contentType = ContentType.json;
      if (isChoose) {
        final items = (body['data'] as List).cast<Map<String, dynamic>>();
        final custom = (body['user'] as Map?)?['custom'];
        request.response.write(
          jsonEncode({
            'user': {'uid': 'u', 'ses': 's'},
            'data': [
              for (final item in items)
                {
                  'selector': null,
                  'payload': [
                    {
                      'campaignId': item['campaignId'],
                      'experienceId': 'e',
                      'variationId': 'v',
                      'decisionId': 'd',
                      'contents': [
                        {
                          'contentId': '${item['campaignId']}-for-$custom',
                          'deliveryMethod': 'modal',
                          'contentType': 'native',
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
      } else {
        request.response.write(
          jsonEncode({
            'user': {'uid': 'u', 'ses': 's'},
            'campaigns': [
              {
                'campaignId': 'high',
                'trigger': 'view',
                'priority': 2,
                'delayTime': 0,
              },
              {
                'campaignId': 'low',
                'trigger': 'view',
                'priority': 1,
                'delayTime': 0,
              },
            ],
          }),
        );
      }
      await request.response.close();
    });
    await GravitySDK.instance.initialize(apiKey: 'k', section: 'sec');
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
    Api.retryDelays = originalRetryDelays;
    OutboxDispatcher.lifecycleObserverEnabled = true;
    GravitySDK.instance.gravityEventCallback = null;
  });

  for (final trigger in [false, true]) {
    for (final change in changes.entries) {
      testWidgets(
        '${trigger ? 'triggerEvent' : 'trackView'} stops old campaign selection after ${change.key}',
        (tester) async {
          late BuildContext host;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (c) {
                  host = c;
                  return const Text('host');
                },
              ),
            ),
          );
          addTearDown(() => tester.pumpWidget(const SizedBox()));
          await tester.runAsync(() async {
            await GravitySDK.instance.resetUser();
            GravitySDK.instance.setUser('user-a', 'ses-a');
            GravitySDK.instance.gravityEventCallback = (e) {
              if (e is ContentLoadEvent) loads.add(e);
            };
            recorded.clear();
            loads.clear();
            arrived = Completer<void>();
            release = Completer<void>();
            holdFirstChoose = true;
            addTearDown(() {
              if (!release!.isCompleted) release!.complete();
            });
            final pending = trigger
                ? GravitySDK.instance.triggerEvent(
                    context: host,
                    events: [CustomEvent(type: 'custom-v1', name: 'x')],
                    pageContext: ctx,
                  )
                : GravitySDK.instance.trackView(
                    context: host,
                    pageContext: ctx,
                  );
            await arrived!.future.timeout(const Duration(seconds: 5));
            await change.value();
            release!.complete();
            await pending;
          });
          await tester.pump();
          final chooses = recorded.where((r) => r.path == '/choose').toList();
          expect(
            chooses,
            hasLength(1),
            reason: 'no fallback /choose from the old trigger list',
          );
          expect(
            ((chooses.single.body['data'] as List).single as Map)['campaignId'],
            'high',
          );
          expect((chooses.single.body['user'] as Map)['custom'], 'user-a');
          expect(loads, isEmpty);
          expect(recorded.where((r) => r.path == '/loaded'), isEmpty);
          expect(find.byType(ModalContent), findsNothing);
        },
      );
    }
  }
}
