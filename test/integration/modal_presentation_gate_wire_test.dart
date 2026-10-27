import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/modal/modal_content.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  var trackingStatus = 503;
  var chooseCount = 0;
  var trackingCount = 0;
  Completer<void>? heldEvent;
  var eventArrived = false;
  const page = PageContext(
    type: ContextType.other,
    data: [],
    location: '/page',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
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
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    Api.retryDelays = const [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/engagement') {
        trackingCount++;
        request.response.statusCode = trackingStatus;
        await request.response.close();
        return;
      }
      await utf8.decoder.bind(request).join();
      if (request.uri.path == '/event' && heldEvent != null) {
        eventArrived = true;
        await heldEvent!.future;
      }
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/choose') {
        chooseCount++;
        request.response.write(
          jsonEncode({
            'user': {'uid': 'server-user', 'ses': 'server-session'},
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
                        'contentId': 'window-$chooseCount',
                        'deliveryMethod': 'modal',
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
                              'http://127.0.0.1:${server.port}/engagement?type=WRIMP&event=$chooseCount',
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
            'user': {'uid': 'server-user', 'ses': 'server-session'},
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
    GravitySDK.instance.setUser('user', 'session');
  });

  tearDownAll(() async {
    GravityRepo.instance.outbox.didChangeAppLifecycleState(
      AppLifecycleState.paused,
    );
    await server.close(force: true);
  });

  testWidgets(
    'parallel requests and pre-ack responses cannot reopen; fresh requests after ack can',
    (tester) async {
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
      final sdk = GravitySDK.instance;
      Future<void> driveRequest(Future<void> Function() action) async {
        var done = false;
        Object? failure;
        await tester.runAsync(() async {
          unawaited(
            action().then(
              (_) {
                done = true;
              },
              onError: (Object error) {
                failure = error;
                done = true;
              },
            ),
          );
        });
        for (var i = 0; i < 300 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(
          done,
          isTrue,
          reason:
              'request did not complete while advancing frame and IO clocks',
        );
        if (failure != null) throw failure!;
      }

      // Both calls run before either /visit answers. One presentation wins.
      await tester.runAsync(
        () => Future.wait([
          sdk.trackView(context: host, pageContext: page),
          sdk.trackView(context: host, pageContext: page),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ModalContent), findsOneWidget);
      expect(chooseCount, 1);

      // Wait for the painted-frame enqueue and network attempt to finish.
      for (var i = 0; i < 100 && trackingCount == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        trackingCount,
        greaterThan(0),
        reason:
            'fired=${tester.widget<ModalContent>(find.byType(ModalContent)).impression!.fired}, draining=${GravityRepo.instance.outbox.isDraining}, queue=${GravityRepo.instance.outbox.snapshot.map((e) => e.toJson()).toList()}',
      );
      Navigator.of(host).pop();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => sdk.pendingDeliveries), 1);
      await driveRequest(() => sdk.trackView(context: host, pageContext: page));
      await tester.pumpAndSettle();
      expect(find.byType(ModalContent), findsNothing);
      expect(
        chooseCount,
        1,
        reason: 'pending durable WRIMP blocks before /choose',
      );

      // This trigger began before the acknowledgement, but its /event response
      // arrives afterwards. It must not reopen even after pending storage clears.
      heldEvent = Completer<void>();
      late Future<void> stale;
      await tester.runAsync(() async {
        stale = sdk.triggerEvent(
          context: host,
          events: [CustomEvent(type: 'custom-v1', name: 'held')],
          pageContext: page,
        );
      });
      for (var i = 0; i < 100 && !eventArrived; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(eventArrived, isTrue);
      trackingStatus = 204;
      // The drain was raised in the frame zone; interleave frame and real IO
      // until its acknowledgement reaches the store.
      late Future<void> flush;
      await tester.runAsync(() async {
        flush = sdk.flushQueue();
      });
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        if (!GravityRepo.instance.outbox.snapshot.any(
          (entry) => entry.isModalImpression,
        )) {
          break;
        }
      }
      await tester.runAsync(() => flush);
      expect(
        GravityRepo.instance.outbox.snapshot.where(
          (entry) => entry.isModalImpression,
        ),
        isEmpty,
      );
      heldEvent!.complete();
      await driveRequest(() => stale);
      await tester.pumpAndSettle();
      expect(find.byType(ModalContent), findsNothing);
      expect(chooseCount, 1);
      heldEvent = null;
      await driveRequest(() => sdk.trackView(context: host, pageContext: page));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(ModalContent),
        findsOneWidget,
        reason: 'no permanent/session local cap',
      );
      expect(chooseCount, 2);
      await tester.pumpWidget(const SizedBox());
      await driveRequest(() => GravityRepo.instance.outbox.clear());
      await tester.pump(const Duration(seconds: 30));
    },
  );
}
