import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:gravity_sdk/src/utils/identity_version.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  var trackingStatus = 503;
  var stepFlow = false;
  var noCampaigns = false;
  var trackLifecycle = false;
  var chooseCount = 0;
  String? chooseTemplate = 'snackbar-1';
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
      request.response.persistentConnection = false;
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
                        'deliveryMethod': 'snackbar',
                        'templateSystemName': ?chooseTemplate,
                        'contentType': 'native',
                        'variables': {
                          if (trackLifecycle) 'onImpression': {'action': 'impression'},
                          if (trackLifecycle) 'onClose': {'action': 'close'},
                          'frameUI': {
                            'params': {'duration': 30},
                            'container': {
                              'style': {'backgroundColor': '#ffffffff'},
                            },
                          },
                          'elements': [
                            if (stepFlow)
                              {
                                'type': 'image',
                                'src': 'http://127.0.0.1:${server.port}/step.png',
                                'style': {'size': {'width': 24, 'height': 24}},
                                'onClick': {'action': 'open_step', 'step': 2},
                              },
                            {
                              'type': 'text',
                              'text': 'Window',
                              'style': {'fontSize': 20},
                            },
                          ],
                        },
                        'events': [
                          if (trackLifecycle) {'type': 'impression', 'urls': []},
                          if (trackLifecycle) {'type': 'close', 'urls': []},
                          {
                            'type': 'visible_impression',
                            'urls': [
                              'http://127.0.0.1:${server.port}/engagement?type=WRIMP&event=$chooseCount',
                            ],
                          },
                        ],
                      },
                      if (stepFlow)
                        {
                          'contentId': 'modal-step',
                          'step': 2,
                          'deliveryMethod': 'modal',
                          'contentType': 'native',
                          'variables': {
                            'frameUI': {'container': {'style': {'backgroundColor': '#ffffffff'}}},
                            'elements': [{'type': 'text', 'text': 'Modal step', 'style': {'fontSize': 20}}],
                          },
                          'events': [{
                            'type': 'visible_impression',
                            'urls': ['http://127.0.0.1:${server.port}/engagement?type=WRIMP&step=2'],
                          }],
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
              if (!noCampaigns) {
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

  // Each widget test owns a FakeAsync zone. Error reporting can read identity
  // in that zone, so detach only the disposed zone's queue before the next
  // test starts (the same boundary used by the other identity wire suites).
  setUp(() => SessionManager.instance.resetIdentityQueueForTests());

  tearDownAll(() async {
    GravityRepo.instance.outbox.didChangeAppLifecycleState(
      AppLifecycleState.paused,
    );
    await server.close(force: true);
  });

  testWidgets(
    'snackbar WRIMP persists and prevents reopening until ack; stale responses stay blocked',
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
      Future<void> driveRequest(Future<void> Function() action) => _driveFuture(tester, action);

      // Both calls run before either /visit answers. One presentation wins.
      await tester.runAsync(
        () => Future.wait([
          sdk.trackView(context: host, pageContext: page),
          sdk.trackView(context: host, pageContext: page),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        trackingCount,
        0,
        reason: 'snackbar waits one second before WRIMP',
      );
      await tester.runAsync(
        () => sdk.triggerEvent(
          context: host,
          events: [CustomEvent(type: 'probe', name: 'probe')],
          pageContext: page,
        ),
      );
      expect(
        chooseCount,
        1,
        reason: 'reservation remains owned before visibility',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Window'), findsOneWidget);
      expect(chooseCount, 1);

      // Wait for the painted-frame enqueue and network attempt to finish.
      while (trackingCount == 0) {
        await tester.runAsync(
          () => Future<void>(() {}),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        trackingCount,
        greaterThan(0),
        reason:
            'snackbar visibility must enqueue WRIMP without variables.onVisibleImpression',
      );
      await tester.fling(find.text('Window'), const Offset(0, -100), 1000);
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => sdk.pendingDeliveries), 1);
      await driveRequest(() => sdk.trackView(context: host, pageContext: page));
      await tester.pumpAndSettle();
      expect(find.text('Window'), findsNothing);
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
      while (!eventArrived) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>(() {}),
        );
      }
      expect(eventArrived, isTrue);
      trackingStatus = 204;
      await driveRequest(sdk.flushQueue);
      expect(
        GravityRepo.instance.outbox.snapshot.where(
          (entry) => entry.isModalImpression,
        ),
        isEmpty,
      );
      heldEvent!.complete();
      await driveRequest(() => stale);
      await tester.pumpAndSettle();
      expect(find.text('Window'), findsNothing);
      expect(chooseCount, 1);
      heldEvent = null;
      await driveRequest(() => sdk.trackView(context: host, pageContext: page));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Window'),
        findsOneWidget,
        reason: 'no permanent/session local cap',
      );
      expect(chooseCount, 2);
      await tester.pumpWidget(const SizedBox());
      await driveRequest(() => GravityRepo.instance.outbox.clear());
      await tester.pump(const Duration(seconds: 30));
    },
  );

  for (final template in ['snackbar-1', 'snackbar-2']) {
    testWidgets('DF-2 trackView keeps one attached showing and one choose ($template)', (tester) async {
      final sdk = GravitySDK.instance;
      final repo = GravityRepo.instance;
      chooseTemplate = template;
      chooseCount = 0;
      trackingCount = 0;
      noCampaigns = false;
      trackLifecycle = true;
      trackingStatus = 200;
      final lifecycle = <Object>[];
      final queued = <List<String>>[];
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      GravityRepo.triggerEventUrlsObserver = (urls) {
        if (urls.any((url) => url.contains('type=WRIMP'))) queued.add(urls);
      };
      addTearDown(() {
        sdk.gravityEventCallback = null;
        GravityRepo.triggerEventUrlsObserver = null;
        VisibilityDetectorController.instance.updateInterval = interval;
        trackLifecycle = false;
      });
      await tester.runAsync(() => sdk.initialize(apiKey: 'key', section: 'DF-2-$template', logLevel: LogLevel.none));
      sdk.setUser('DF-2-$template', 'session');
      sdk.gravityEventCallback = lifecycle.add;
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      })));
      await tester.runAsync(() => sdk.trackView(context: host, pageContext: page));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Window'), findsOneWidget);
      expect(lifecycle.whereType<ContentImpressionEvent>(), hasLength(1));
      expect(queued, isEmpty, reason: 'attached before the one-second WRIMP threshold');
      // Return the SAME campaign; the old S6 fixture returned no campaigns here.
      await tester.runAsync(() => sdk.trackView(context: host, pageContext: page));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final instancesBeforeWrimp = find.text('Window').evaluate().length;
      final choosesBeforeWrimp = chooseCount;
      await tester.pump(const Duration(seconds: 1));
      await _driveFuture(tester, repo.outbox.load);
      await _driveFuture(tester, repo.outbox.flush);
      // An acknowledged WRIMP must not end protection while still attached.
      await tester.runAsync(() => sdk.trackView(context: host, pageContext: page));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final finalInstances = find.text('Window').evaluate().length;
      final finalChooses = chooseCount;
      final impressions = lifecycle.whereType<ContentImpressionEvent>().length;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
      await _driveFuture(tester, repo.outbox.clear);
      expect({
        'instancesBeforeWrimp': instancesBeforeWrimp,
        'choosesBeforeWrimp': choosesBeforeWrimp,
        'instancesAfterAck': finalInstances,
        'choosesAfterAck': finalChooses,
        'impressions': impressions,
        'wrimps': queued.length,
      }, {
        'instancesBeforeWrimp': 1,
        'choosesBeforeWrimp': 1,
        'instancesAfterAck': 1,
        'choosesAfterAck': 1,
        'impressions': 1,
        'wrimps': 1,
      }, reason: 'one attached snackbar, one choose, one impression and WRIMP across trackView and acknowledgement');
    });
  }

  for (final template in [null, 'unsupported-snackbar']) {
    testWidgets(
      'unsupported template $template releases reservation before the next trigger',
      (tester) async {
        final sdk = GravitySDK.instance;
        await tester.runAsync(
          () => sdk.initialize(
            apiKey: 'key',
            section: 'unsupported-$template',
            logLevel: LogLevel.none,
          ),
        );
        chooseTemplate = template;
        chooseCount = 0;
        late BuildContext host;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          ),
        );
        Future<void> trigger() => sdk.triggerEvent(
          context: host,
          events: [CustomEvent(type: 'probe', name: 'probe')],
          pageContext: page,
        );
        await tester.runAsync(trigger);
        await tester.pump();
        expect(chooseCount, 1);
        expect(find.text('Window'), findsNothing);
        await tester.runAsync(trigger);
        await tester.pump();
        expect(
          chooseCount,
          2,
          reason: 'unsupported content must not keep the reservation',
        );
        expect(find.text('Window'), findsNothing);
      },
    );
  }

  testWidgets('anchor snackbar holds one reservation before visibility', (
    tester,
  ) async {
    final sdk = GravitySDK.instance;
    await tester.runAsync(
      () => sdk.initialize(
        apiKey: 'key',
        section: 'anchor-snackbar',
        logLevel: LogLevel.none,
      ),
    );
    chooseTemplate = 'snackbar-1';
    chooseCount = 0;
    trackingCount = 0;
    trackingStatus = 503;
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    Future<void> fetch() => sdk.fetchAnchorContent(
      context: host,
      selector: 'anchor',
      pageContext: page,
    );
    await tester.runAsync(fetch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Window'), findsOneWidget);
    expect(trackingCount, 0);
    await tester.runAsync(fetch);
    await tester.pump();
    await tester.pump();
    expect(
      chooseCount,
      2,
      reason: 'anchors must fetch before they know their campaign',
    );
    expect(
      find.text('Window'),
      findsOneWidget,
      reason: 'second anchor response must use the existing reservation',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
    await tester.runAsync(() => GravityRepo.instance.outbox.clear());
  });
  testWidgets('visible snackbar open_step to modal queues one WRIMP per opening', (tester) async {
    stepFlow = true;
    trackingStatus = 200;
    final queued = <List<String>>[];
    GravityRepo.triggerEventUrlsObserver = queued.add;
    addTearDown(() => GravityRepo.triggerEventUrlsObserver = null);
    chooseTemplate = 'snackbar-1';
    final oldInterval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      stepFlow = false;
      VisibilityDetectorController.instance.updateInterval = oldInterval;
      PaintingBinding.instance.imageCache.clear();
    });
    await tester.runAsync(() => GravitySDK.instance.initialize(
      apiKey: 'key', section: 'snackbar-step-flow', logLevel: LogLevel.none,
    ));
    GravitySDK.instance.setUser('step-user', 'session');
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(1, 1));
    picture.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      NetworkImage('http://127.0.0.1:${server.port}/step.png'),
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
    );
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      host = context;
      return const Scaffold();
    })));
    final repo = GravityRepo.instance;
    await tester.runAsync(() => repo.outbox.clear());
    await tester.runAsync(() => GravitySDK.instance.trackView(context: host, pageContext: page));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Window'), findsOneWidget);
    while (queued.isEmpty) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>(() {}));
    }
    expect(queued, hasLength(1));
    await tester.tap(find.byType(GravityImageWidget).first);
    await tester.pumpAndSettle();
    await _driveFuture(tester, repo.outbox.flush);
    expect(find.text('Modal step'), findsOneWidget);
    final queuedCount = queued.length;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
    await _driveFuture(tester, repo.outbox.clear);
    expect(queuedCount, 1, reason: 'one WRIMP queued across snackbar and modal step');
  });

  for (final template in ['snackbar-1', 'snackbar-2']) {
    for (final action in ['lock', 'trackView', 'lockBeforeAppearance', 'trackViewBeforeAppearance', 'setUserBeforeAppearance', 'resetBeforeAppearance', 'restoreBeforeAppearance']) {
      testWidgets('S6 $action preserves a shown snackbar or suppresses unseen user content ($template)', (tester) async {
        final sdk = GravitySDK.instance;
        final repo = GravityRepo.instance;
        final lifecycle = <Object>[];
        final queued = <List<String>>[];
        final interval = VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        stepFlow = false;
        chooseTemplate = template;
        noCampaigns = false;
        trackLifecycle = true;
        trackingStatus = 200;
        GravityRepo.triggerEventUrlsObserver = (urls) {
          if (urls.any((url) => url.contains('type=WRIMP'))) queued.add(urls);
        };
        addTearDown(() {
          sdk.unlockPresentation();
          sdk.gravityEventCallback = null;
          GravityRepo.triggerEventUrlsObserver = null;
          VisibilityDetectorController.instance.updateInterval = interval;
          noCampaigns = false;
          trackLifecycle = false;
        });
        await tester.runAsync(() => sdk.initialize(apiKey: 'key', section: 'S6-$action-$template', logLevel: LogLevel.none));
        sdk.gravityEventCallback = lifecycle.add;
        sdk.setUser('S6-original-$action-$template', 'session');
        late BuildContext host;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        })));
        await tester.runAsync(() => sdk.trackView(context: host, pageContext: page));
        await tester.pump(); // Insert the overlay; its content attaches next frame.
        Future<void> change() async {
          if (action.startsWith('lock')) {
            sdk.lockPresentation();
          } else if (action.startsWith('trackView')) {
            noCampaigns = true;
            await sdk.trackView(context: host, pageContext: const PageContext(type: ContextType.other, data: [], location: '/S6-next'));
          } else if (action.startsWith('setUser')) {
            sdk.setUser('S6-replaced', 'session');
          } else if (action.startsWith('reset')) {
            await sdk.resetUser();
          } else {
            await sdk.restoreUserId('S6-restored');
          }
        }
        if (action.endsWith('BeforeAppearance')) {
          late Future<void> changed;
          // Registered before initState's impression callback, but runs after
          // the overlay is attached/painted. No real-time scheduling race.
          tester.binding.addPostFrameCallback((_) { changed = tester.runAsync(change).then((_) {}); });
          await tester.pump();
          await changed;
        } else {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.runAsync(change);
        }
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 1));
        await _driveFuture(tester, repo.outbox.load);
        if (queued.isNotEmpty) {
          while (await tester.runAsync(() => repo.outbox.pendingCount) != 0) {
            await tester.pump(const Duration(milliseconds: 1));
            await tester.runAsync(() => Future<void>(() {}));
          }
        }
        final changesUser = action.startsWith('setUser') || action.startsWith('reset') || action.startsWith('restore');
        final impressions = lifecycle.whereType<ContentImpressionEvent>().length;
        final wrimps = queued.length;
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();
        final closes = lifecycle.whereType<ContentCloseEvent>().length;
        await tester.pumpWidget(const SizedBox());
        await _driveFuture(tester, repo.outbox.clear);
        expect(impressions, changesUser ? 0 : 1, reason: 'a screen/lock change must not suppress an attached opening; a user change must');
        expect(wrimps, changesUser ? 0 : 1, reason: 'one durable WRIMP for the still-valid shown user');
        expect(closes, changesUser ? 0 : 1, reason: 'no close callback without its impression');
      });
    }
  }

  for (final template in ['snackbar-1', 'snackbar-2']) {
    for (final change in ['setUser', 'reset', 'restore']) {
      testWidgets('user change during snackbar visibility ($change, $template) suppresses WRIMP', (tester) async {
        final sdk = GravitySDK.instance;
        final repo = GravityRepo.instance;
        stepFlow = false;
        chooseTemplate = template;
        trackingStatus = 200;
        final queued = <List<String>>[];
        final oldInterval = VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        GravityRepo.triggerEventUrlsObserver = (urls) {
          if (urls.any((url) => url.contains('type=WRIMP'))) queued.add(urls);
        };
        addTearDown(() {
          GravityRepo.triggerEventUrlsObserver = null;
          VisibilityDetectorController.instance.updateInterval = oldInterval;
        });
        await tester.runAsync(() => sdk.initialize(
          apiKey: 'key', section: 'visibility-$change-$template', logLevel: LogLevel.none,
        ));
        sdk.setUser('old-$change-$template', 'session');
        final oldScope = GravityRepo.impressionScope(sdk.section, sdk.user);
        late BuildContext host;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        })));
        await tester.runAsync(() => sdk.trackView(context: host, pageContext: page));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Window'), findsOneWidget);
        expect(queued, isEmpty, reason: 'one-second visibility interval is not complete');
        switch (change) {
          case 'setUser':
            sdk.setUser('new-user', 'new-session');
          case 'reset':
            await tester.runAsync(sdk.resetUser);
          case 'restore':
            await tester.runAsync(() => sdk.restoreUserId('restored-user'));
        }
        await tester.pump(const Duration(seconds: 2));
        final queuedAfterChange = queued.length;
        // The next request invalidates unshown reservations from the old user.
        final gate = InAppPresentationGate.instance;
        final request = gate.beginRequest(page.location, IdentityVersion.current);
        final probe = gate.reserve(oldScope, 'campaign', request);
        final oldReservationReleased = probe != null;
        if (probe != null) gate.cancel(probe);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 31));
        await _driveFuture(tester, repo.outbox.clear);
        expect(queuedAfterChange, 0, reason: 'old-user snackbar must never enqueue WRIMP');
        expect(oldReservationReleased, isTrue, reason: 'old-user unshown reservation is invalidated');
      });
    }
  }

}

// Advance the widget microtask zone and the real IO event loop until the
// operation itself signals completion. No wall-clock sleep or iteration cap.
Future<void> _driveFuture(WidgetTester tester, Future<void> Function() action) async {
  var done = false;
  Object? failure;
  StackTrace? stack;
  await tester.runAsync(() async {
    unawaited(action().then((_) => done = true, onError: (Object error, StackTrace trace) {
      failure = error;
      stack = trace;
      done = true;
    }));
  });
  while (!done) {
    await tester.pump();
    await tester.runAsync(() => Future<void>(() {}));
  }
  if (failure != null) Error.throwWithStackTrace(failure!, stack!);
}
