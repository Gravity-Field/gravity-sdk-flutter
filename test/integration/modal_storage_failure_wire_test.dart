import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

import '../support/draining_http_overrides.dart';

void main() {
  final transport = DrainingHttpOverrides();
  Completer<void>? releaseWrimp;
  late HttpServer server;
  var chooses = 0;
  var wrimps = 0;
  var format = 'modal';
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = transport;
    // SharedPreferences.getString throws for this key only. Identity reads
    // remain available, reproducing an outbox failure rather than all prefs.
    SharedPreferences.setMockInitialValues({'gravity_outbox': 42});
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'test',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    DeviceUtils.instance.debugDevice = const Device(
      userAgent: 'test',
      id: 'test',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/engagement') {
        wrimps++;
        await releaseWrimp?.future;
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/choose') {
        chooses++;
        request.response.write(
          jsonEncode({
            'user': {'uid': 'u', 'ses': 's'},
            'data': [
              {
                'payload': [
                  {
                    'campaignId': 'campaign',
                    'experienceId': 'e',
                    'variationId': 'v',
                    'decisionId': 'd',
                    'contents': [
                      {
                        'contentId': 'content',
                        'deliveryMethod': format,
                        'contentType': 'native',
                        'variables': {
                          'frameUI': {
                            'container': {
                              'style': {'backgroundColor': '#ffffffff'},
                            },
                          },
                          'elements': [
                            {
                              'type': 'text',
                              'text': 'Window',
                              'style': {'fontSize': 20},
                            },
                          ],
                        },
                        'events': [
                          {
                            'type': 'visible_impression',
                            'urls': [
                              'http://127.0.0.1:${server.port}/engagement?type=WRIMP&user=original',
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
                'campaignId': 'campaign',
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
    await GravitySDK.instance.initialize(
      apiKey: 'key',
      section: 'section',
      logLevel: LogLevel.none,
    );
    GravitySDK.instance.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
    GravitySDK.instance.setUser('original', 's');
  });
  tearDownAll(() async {
    GravityRepo.instance.outbox.didChangeAppLifecycleState(
      AppLifecycleState.paused,
    );
    await server.close(force: true);
  });
  for (final modal in [true, false]) {
    for (final trigger in [false, true]) {
      testWidgets(
        '${trigger ? 'triggerEvent' : 'trackView'} still chooses ${modal ? 'modal and sends WRIMP best effort' : 'non-modal'} despite outbox read failure',
        (tester) async {
          releaseWrimp = modal ? Completer<void>() : null;
          final completedBefore = transport.completed.length;
          format = modal ? 'modal' : 'inline';
          final before = chooses;
          final beforeWrimps = wrimps;
          GravitySDK.instance.setUser('storage-user-$chooses', 'session');
          late BuildContext host;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  host = context;
                  return const Scaffold(body: Text('Host'));
                },
              ),
            ),
          );
          await tester.runAsync(
            () => trigger
                ? GravitySDK.instance.triggerEvent(
                    context: host,
                    events: [
                      CustomEvent(type: 'custom-v1', name: 'read-failure'),
                    ],
                    pageContext: const PageContext(
                      type: ContextType.other,
                      data: [],
                      location: '/storage',
                    ),
                  )
                : GravitySDK.instance.trackView(
                    context: host,
                    pageContext: const PageContext(
                      type: ContextType.other,
                      data: [],
                      location: '/storage',
                    ),
                  ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(chooses, before + 1);
          if (modal) {
            expect(find.byType(ModalContent), findsOneWidget);
            for (var i = 0; i < 100 && wrimps == beforeWrimps; i++) {
              await tester.pump(const Duration(milliseconds: 20));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
            }
            expect(wrimps, beforeWrimps + 1);
            expect(
              transport.completed
                  .skip(completedBefore)
                  .where((uri) => uri.path == '/engagement'),
              isEmpty,
              reason:
                  'server receipt must not be mistaken for client completion',
            );
          }
          await tester.pumpWidget(const SizedBox());
          // The UI owns no awaitable handle to best-effort WRIMP. Release the
          // server response and wait for the real client stream to finish,
          // rather than advancing fake time while socket IO is outstanding.
          releaseWrimp?.complete();
          final deadline = Stopwatch()..start();
          while (transport.pending.isNotEmpty &&
              deadline.elapsed < const Duration(seconds: 5)) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 1)),
            );
            await tester.pump(Duration.zero);
          }
          expect(
            transport.pending,
            isEmpty,
            reason:
                'all client response streams must finish before test teardown',
          );
          // Dio schedules zero-duration response-interceptor timers after the
          // stream closes; pump() alone flushes microtasks, not these timers.
          await tester.pump(Duration.zero);
          if (modal) {
            expect(
              transport.completed
                  .skip(completedBefore)
                  .where((uri) => uri.path == '/engagement'),
              hasLength(1),
            );
          }
        },
      );
    }
  }
}
