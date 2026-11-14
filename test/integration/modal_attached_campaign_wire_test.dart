import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/api/api.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/models/internal/device.dart';
import 'package:gravity_sdk/src/ui/widgets/close_button.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/modal/modal_content.dart';
import 'package:gravity_sdk/src/utils/clock.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/draining_http_overrides.dart';

class _Routes extends NavigatorObserver {
  final active = <Route<dynamic>>[];
  int get modalCount => active.length - 1;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      active.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      active.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      active.remove(route);
}

void main() {
  final sdk = GravitySDK.instance;
  final transport = DrainingHttpOverrides();
  final events = <TrackingEvent>[];
  final requests = <String>[];
  late HttpServer server;
  var method = 'modal';
  Map<String, dynamic>? stepOverride;
  var caseId = 0;
  var now = DateTime(2026, 1, 1);
  const page = PageContext(
    type: ContextType.other,
    data: [],
    location: '/attached',
  );

  Map<String, dynamic> contentJson({int step = 0}) => {
    'contentId': 'content-$step',
    if (step != 0) 'step': step,
    'deliveryMethod': method,
    'contentType': 'native',
    'variables': {
      'frameUI': {
        'container': {'style': <String, dynamic>{}},
        'close': {
          'onClick': {'action': 'close'},
        },
      },
      'onImpression': {'action': 'impression'},
      'onClose': {'action': 'close'},
      'elements': [
        {
          'type': 'text',
          'text': 'Window $step',
          'style': {'fontSize': 20},
        },
        if (step < 2)
          {
            'type': 'button',
            'text': 'Next',
            'style': {'fontSize': 20},
            'onClick': {'action': 'open_step', 'step': 2},
          },
      ],
    },
    'events': [
      {
        'type': 'impression',
        'urls': ['http://127.0.0.1:${server.port}/impression'],
      },
      {
        'type': 'close',
        'urls': ['http://127.0.0.1:${server.port}/close'],
      },
      // Deliberately no visible_impression (WRIMP) tracking URL.
    ],
  };
  Map<String, dynamic> campaignJson({String? campaignId}) => {
    'payload': [
      {
        'campaignId': campaignId ?? 'campaign-$caseId',
        'experienceId': 'e',
        'variationId': 'v',
        'decisionId': 'd',
        'contents': [
          contentJson(),
          contentJson(step: 1),
          stepOverride ?? contentJson(step: 2),
        ],
      },
    ],
  };
  final inline = CampaignContent.fromJson({
    'contentId': 'inline',
    'deliveryMethod': 'inline',
    'contentType': 'native',
    'variables': <String, dynamic>{},
  });

  setUpAll(() async {
    HttpOverrides.global = transport;
    SharedPreferences.setMockInitialValues({});
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
      request.response.persistentConnection = false;
      requests.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      if (request.uri.path == '/impression' || request.uri.path == '/close') {
        request.response.statusCode = 204;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'user': {'uid': 'server-user', 'ses': 's'},
            if (request.uri.path == '/choose')
              'data': [campaignJson()]
            else
              'campaigns': [
                {
                  'campaignId': 'campaign-$caseId',
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
    await sdk.initialize(
      apiKey: 'key',
      section: 'section',
      logLevel: LogLevel.none,
      gravityEventCallback: events.add,
    );
    sdk.setOptions(proxyUrl: 'http://127.0.0.1:${server.port}');
    Clock.now = () => now;
  });
  setUp(() {
    caseId++;
    stepOverride = null;
    sdk.setUser('user-$caseId', 'session');
    requests.clear();
    events.clear();
  });
  tearDownAll(() async {
    Clock.now = DateTime.now;
    sdk.gravityEventCallback = null;
    OutboxDispatcher.lifecycleObserverEnabled = true;
    await server.close(force: true);
  });

  int count(String path) => requests.where((request) => request == path).length;

  Future<void> settle(WidgetTester tester, {int? closes}) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pump(Duration.zero);
    final elapsed = Stopwatch()..start();
    while ((transport.pending.isNotEmpty ||
            (closes != null && count('/close') < closes)) &&
        elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(Duration.zero);
    }
    expect(transport.pending, isEmpty);
    await tester.pump(Duration.zero);
  }

  Future<BuildContext> mount(WidgetTester tester, _Routes routes) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: Text('Host'));
          },
        ),
      ),
    );
    return host;
  }

  Future<void> present(
    WidgetTester tester,
    BuildContext host,
    String entry, {
    String? campaignId,
  }) async {
    await tester.runAsync(() async {
      switch (entry) {
        case 'visit':
          await sdk.trackView(context: host, pageContext: page);
        case 'event':
          await sdk.triggerEvent(
            context: host,
            events: [CustomEvent(type: 'custom-v1', name: 'again')],
            pageContext: page,
          );
        case 'anchor':
          await sdk.fetchAnchorContent(
            context: host,
            selector: 'attached',
            pageContext: page,
          );
        case 'openStep':
          sdk.openStep(
            context: host,
            onClick: OnClick(action: Action.openStep, step: 1),
            currentContent: inline,
            campaign: Campaign.fromJson(campaignJson(campaignId: campaignId)),
          );
      }
    });
    await settle(tester);
  }

  for (final target in [
    'json',
    'inline',
    'unknown-delivery',
    'snackbar',
    'bottom_sheet',
  ]) {
    testWidgets('non-presentable step $target releases the campaign', (
      tester,
    ) async {
      method = 'modal';
      stepOverride = {
        'contentId': 'dead-end',
        'step': 2,
        'deliveryMethod': target,
        'contentType': 'native',
        'variables': <String, dynamic>{},
      };
      final routes = _Routes();
      final host = await mount(tester, routes);
      try {
        await present(tester, host, 'visit');
        expect((routes.modalCount, count('/impression')), (1, 1));
        await tester.tap(find.text('Next'));
        await settle(tester);
        expect(routes.modalCount, 0);
        now = now.add(const Duration(seconds: 61));
        await tester.pump(const Duration(seconds: 61));
        await present(tester, host, 'visit');
        expect(
          (routes.modalCount, count('/impression')),
          (1, 2),
          reason: 'a failed step must release the campaign for a later opening',
        );
        expect(count('/close'), 1);
        expect(events.whereType<ContentCloseEvent>(), hasLength(1));
        Navigator.of(host).pop();
        await settle(tester, closes: 2);
        expect(count('/close'), 2);
        expect(events.whereType<ContentCloseEvent>(), hasLength(2));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });
  }

  testWidgets(
    'abandoned step before appearance releases without close tracking',
    (tester) async {
      method = 'modal';
      stepOverride = {
        'contentId': 'dead-end',
        'step': 2,
        'deliveryMethod': 'json',
        'contentType': 'native',
        'variables': <String, dynamic>{},
      };
      final routes = _Routes();
      final host = await mount(tester, routes);
      try {
        sdk.openStep(
          context: host,
          onClick: OnClick(action: Action.openStep, step: 1),
          currentContent: inline,
          campaign: Campaign.fromJson(campaignJson()),
        );
        // Build the first route at animation value zero, before visible paint.
        await tester.pump();
        final modal = tester.widget<ModalContent>(find.byType(ModalContent));
        expect(modal.impression!.fired, isFalse);
        sdk.openStep(
          context: tester.element(find.text('Next')),
          onClick: OnClick(action: Action.openStep, step: 2),
          currentContent: modal.content,
          campaign: modal.campaign,
          session: modal.session,
          impression: modal.impression,
        );
        await settle(tester);
        expect(routes.modalCount, 0);
        expect(count('/close'), 0);
        expect(events.whereType<ContentCloseEvent>(), isEmpty);
        await present(tester, host, 'openStep');
        expect(routes.modalCount, 1);
        Navigator.of(host).pop();
        await settle(tester, closes: 1);
        expect(count('/close'), 1);
        expect(events.whereType<ContentCloseEvent>(), hasLength(1));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    },
  );

  for (final interruption in ['overlay error', 'user change', 'reinitialize']) {
    testWidgets('deferred snackbar step releases on $interruption', (
      tester,
    ) async {
      method = 'modal';
      stepOverride = {
        ...contentJson(step: 2),
        'deliveryMethod': 'snackbar',
        'templateSystemName': 'snackbar-1',
      };
      final routes = _Routes();
      final host = await mount(tester, routes);
      final reports = <String>[];
      ErrorReporter.observer = (section, payload) => reports.add(section);
      try {
        await present(tester, host, 'visit');
        await tester.tap(find.text('Next'));
        if (interruption == 'user change') {
          sdk.setUser('changed-$caseId', 'new-session');
        } else if (interruption == 'reinitialize') {
          await tester.runAsync(
            () => sdk.initialize(
              apiKey: 'key',
              section: 'section',
              logLevel: LogLevel.none,
              gravityEventCallback: events.add,
            ),
          );
        }
        await settle(tester, closes: 1);
        expect(routes.modalCount, 0);
        expect(count('/close'), 1);
        expect(events.whereType<ContentCloseEvent>(), hasLength(1));
        if (interruption == 'overlay error') {
          // The root Navigator's context has no ancestor Overlay. The
          // deferred snackbar presenter catches this failure before attach.
          expect(reports, contains('SnackBarContent.show'));
        }
        await present(tester, host, 'openStep');
        expect(routes.modalCount, 1);
        Navigator.of(host).pop();
        await settle(tester, closes: 2);
        expect(count('/close'), 2);
        expect(events.whereType<ContentCloseEvent>(), hasLength(2));
      } finally {
        ErrorReporter.observer = null;
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });
  }

  testWidgets('missing Navigator cannot poison an attached step session', (
    tester,
  ) async {
    method = 'modal';
    final routes = _Routes();
    late BuildContext outsideNavigator;
    late BuildContext host;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          outsideNavigator = context;
          return MaterialApp(
            navigatorObservers: [routes],
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold();
              },
            ),
          );
        },
      ),
    );
    try {
      await present(tester, host, 'openStep');
      final modal = tester.widget<ModalContent>(find.byType(ModalContent));
      expect(
        () => sdk.openStep(
          context: outsideNavigator,
          onClick: OnClick(action: Action.openStep, step: 2),
          currentContent: modal.content,
          campaign: modal.campaign,
          session: modal.session,
          impression: modal.impression,
        ),
        throwsA(isA<FlutterError>()),
      );
      await present(tester, host, 'openStep');
      expect((routes.modalCount, count('/impression')), (1, 1));
      Navigator.of(host).pop();
      await settle(tester, closes: 1);
      expect(count('/close'), 1);
      expect(events.whereType<ContentCloseEvent>(), hasLength(1));
      await present(tester, host, 'openStep');
      expect((routes.modalCount, count('/impression')), (1, 2));
    } finally {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    }
  });

  for (final delivery in ['modal', 'bottom_sheet']) {
    testWidgets(
      '$delivery presentation exception releases a claim on a live Navigator',
      (tester) async {
        method = delivery;
        final badRoutes = _Routes();
        final goodRoutes = _Routes();
        late BuildContext badHost;
        late BuildContext goodHost;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: WidgetsApp(
                    color: Colors.white,
                    navigatorObservers: [badRoutes],
                    onGenerateRoute: (_) => PageRouteBuilder<void>(
                      pageBuilder: (context, animation, secondaryAnimation) {
                        badHost = context;
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: MaterialApp(
                    navigatorObservers: [goodRoutes],
                    home: Builder(
                      builder: (context) {
                        goodHost = context;
                        return const Scaffold();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        expect(
          Localizations.of<MaterialLocalizations>(
            badHost,
            MaterialLocalizations,
          ),
          isNull,
        );
        try {
          await present(tester, badHost, 'openStep');
          expect(badRoutes.modalCount, 0);
          expect(count('/impression'), 0);
          expect(count('/close'), 0);
          // Keep the failing Navigator mounted: dead-owner pruning must not
          // hide a claim leaked by the presentation exception.
          await present(tester, goodHost, 'openStep');
          expect((goodRoutes.modalCount, count('/impression')), (1, 1));
          Navigator.of(goodHost).pop();
          await settle(tester, closes: 1);
          expect(count('/close'), 1);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      },
    );
  }

  for (final delivery in ['modal', 'bottom_sheet', 'full_screen']) {
    testWidgets('$delivery missing Navigator cancels an unshown reservation', (
      tester,
    ) async {
      method = delivery;
      final routes = _Routes();
      late BuildContext outsideNavigator;
      late BuildContext host;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            outsideNavigator = context;
            return MaterialApp(
              navigatorObservers: [routes],
              home: Builder(
                builder: (context) {
                  host = context;
                  return const Scaffold();
                },
              ),
            );
          },
        ),
      );
      try {
        await present(tester, outsideNavigator, 'anchor');
        expect((routes.modalCount, count('/impression')), (0, 0));
        expect(count('/close'), 0);
        await present(tester, host, 'anchor');
        expect((routes.modalCount, count('/impression')), (1, 1));
        Navigator.of(host).pop();
        await settle(tester, closes: 1);
        expect(count('/close'), 1);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });

    testWidgets('$delivery releases a step popped before attachment', (
      tester,
    ) async {
      method = delivery;
      final routes = _Routes();
      final host = await mount(tester, routes);
      try {
        await present(tester, host, 'openStep');
        await tester.tap(find.text('Next'));
        Navigator.of(host).pop();
        await settle(tester, closes: 1);
        expect(routes.modalCount, 0);
        expect(count('/close'), 1);
        expect(events.whereType<ContentCloseEvent>(), hasLength(1));
        await present(tester, host, 'openStep');
        expect((routes.modalCount, count('/impression')), (1, 2));
        Navigator.of(host).pop();
        await settle(tester, closes: 2);
        expect(count('/close'), 2);
        expect(events.whereType<ContentCloseEvent>(), hasLength(2));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });

    testWidgets(
      '$delivery releases a step whose host unmounts before attachment',
      (tester) async {
        method = delivery;
        var routes = _Routes();
        var host = await mount(tester, routes);
        try {
          await present(tester, host, 'openStep');
          final staleContext = tester.element(find.text('Next'));
          await tester.tap(find.text('Next'));
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
          // A late action from an unmounted widget must not begin another step.
          sdk.openStep(
            context: staleContext,
            onClick: OnClick(action: Action.openStep, step: 2),
            currentContent: inline,
            campaign: Campaign.fromJson(campaignJson()),
          );
          routes = _Routes();
          host = await mount(tester, routes);
          await present(tester, host, 'openStep');
          expect((routes.modalCount, count('/impression')), (1, 2));
          Navigator.of(host).pop();
          await settle(tester, closes: 1);
          expect(count('/close'), 1);
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      },
    );

    for (final identityChange in ['user change', 'reinitialize']) {
      testWidgets(
        '$delivery step stays guarded through $identityChange before attachment',
        (tester) async {
          method = delivery;
          final routes = _Routes();
          final host = await mount(tester, routes);
          try {
            await present(tester, host, 'visit');
            await tester.tap(find.text('Next'));
            if (identityChange == 'user change') {
              sdk.setUser('changed-$caseId', 'new-session');
            } else {
              await tester.runAsync(
                () => sdk.initialize(
                  apiKey: 'key',
                  section: 'section',
                  logLevel: LogLevel.none,
                  gravityEventCallback: events.add,
                ),
              );
            }
            await settle(tester);
            expect(find.text('Window 2'), findsOneWidget);
            expect((routes.modalCount, count('/impression')), (1, 2));
            await present(tester, host, 'openStep');
            expect((routes.modalCount, count('/impression')), (1, 2));
            expect(count('/close'), 0);
            Navigator.of(host).pop();
            await settle(tester, closes: 1);
            expect(count('/close'), 1);
            expect(events.whereType<ContentCloseEvent>(), hasLength(1));
            await present(tester, host, 'openStep');
            expect((routes.modalCount, count('/impression')), (1, 3));
            Navigator.of(host).pop();
            await settle(tester, closes: 2);
            expect(count('/close'), 2);
            expect(events.whereType<ContentCloseEvent>(), hasLength(2));
          } finally {
            await tester.pumpWidget(const SizedBox());
            await settle(tester);
          }
        },
      );
    }

    for (final entry in ['visit', 'event', 'anchor', 'openStep']) {
      testWidgets('$delivery no-WRIMP stays single after 60s via $entry', (
        tester,
      ) async {
        method = delivery;
        final routes = _Routes();
        final host = await mount(tester, routes);
        try {
          await present(tester, host, entry);
          expect(routes.modalCount, 1);
          expect(count('/impression'), 1);
          now = now.add(const Duration(seconds: 61));
          await tester.pump(const Duration(seconds: 61));
          await present(tester, host, entry);
          expect(
            (routes.modalCount, count('/impression')),
            (1, 1),
            reason:
                'an attached campaign cannot stack another route or impression after the gate expires',
          );
          expect(count('/impression'), 1);
          expect(events.whereType<ContentCloseEvent>(), isEmpty);
          Navigator.of(host).pop();
          await settle(tester, closes: 1);
          expect(routes.modalCount, 0);
          expect(count('/close'), 1);
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          await present(tester, host, entry);
          expect(
            routes.modalCount,
            1,
            reason: 'closing releases the live presentation guard',
          );
          expect(count('/impression'), 2);
          Navigator.of(host).pop();
          await settle(tester, closes: 2);
          expect(count('/close'), 2);
          expect(events.whereType<ContentCloseEvent>(), hasLength(2));
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      });
    }

    testWidgets(
      '$delivery allows a different campaign while guarding each live campaign',
      (tester) async {
        method = delivery;
        final routes = _Routes();
        final host = await mount(tester, routes);
        final secondCampaign = 'campaign-$caseId-second';
        try {
          await present(tester, host, 'openStep');
          final firstRoute = routes.active.last;
          expect((routes.modalCount, count('/impression')), (1, 1));
          await present(tester, host, 'openStep');
          expect((routes.modalCount, count('/impression')), (1, 1));

          await present(tester, host, 'openStep', campaignId: secondCampaign);
          expect(
            (routes.modalCount, count('/impression')),
            (2, 2),
            reason:
                'another campaign may open while the first is still attached',
          );
          expect(routes.active, contains(firstRoute));
          await present(tester, host, 'openStep', campaignId: secondCampaign);
          await present(tester, host, 'openStep');
          expect((routes.modalCount, count('/impression')), (2, 2));
          expect(count('/close'), 0);
          expect(events.whereType<ContentCloseEvent>(), isEmpty);

          Navigator.of(host).pop();
          await settle(tester, closes: 1);
          expect(routes.active.last, same(firstRoute));
          await present(tester, host, 'openStep');
          expect(
            (routes.modalCount, count('/impression')),
            (1, 2),
            reason: 'closing the second campaign keeps the first guarded',
          );
          Navigator.of(host).pop();
          await settle(tester, closes: 2);
          expect(routes.modalCount, 0);
          expect(count('/close'), 2);
          expect(events.whereType<ContentCloseEvent>(), hasLength(2));
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      },
    );

    testWidgets(
      '$delivery allows a step transition within the attached opening',
      (tester) async {
        method = delivery;
        final routes = _Routes();
        final host = await mount(tester, routes);
        try {
          await present(tester, host, 'openStep');
          await tester.tap(find.text('Next'));
          await settle(tester);
          expect(routes.modalCount, 1);
          expect(find.text('Window 2'), findsOneWidget);
          expect(count('/impression'), 2);
          expect(events.whereType<ContentCloseEvent>(), isEmpty);
          now = now.add(const Duration(seconds: 61));
          await present(tester, host, 'visit');
          expect(routes.modalCount, 1);
          expect(count('/impression'), 2);
          Navigator.of(host).pop();
          await settle(tester, closes: 1);
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          expect(count('/close'), 1);
          await present(tester, host, 'openStep');
          expect(routes.modalCount, 1);
          expect(count('/impression'), 3);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      },
    );

    testWidgets('$delivery releases an opening closed before its first frame', (
      tester,
    ) async {
      method = delivery;
      final routes = _Routes();
      final host = await mount(tester, routes);
      try {
        sdk.openStep(
          context: host,
          onClick: OnClick(action: Action.openStep, step: 1),
          currentContent: inline,
          campaign: Campaign.fromJson(campaignJson()),
        );
        Navigator.of(host).pop();
        await settle(tester);
        expect(events.whereType<ContentCloseEvent>(), isEmpty);
        expect(count('/close'), 0);
        await present(tester, host, 'openStep');
        expect(routes.modalCount, 1);
        expect(count('/impression'), 1);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });

    testWidgets('$delivery refuses a second opening before the first frame', (
      tester,
    ) async {
      method = delivery;
      final routes = _Routes();
      final host = await mount(tester, routes);
      try {
        for (var i = 0; i < 2; i++) {
          sdk.openStep(
            context: host,
            onClick: OnClick(action: Action.openStep, step: 1),
            currentContent: inline,
            campaign: Campaign.fromJson(campaignJson()),
          );
        }
        await settle(tester);
        expect((routes.modalCount, count('/impression')), (1, 1));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });

    testWidgets('$delivery releases a host destroyed before the first frame', (
      tester,
    ) async {
      method = delivery;
      var routes = _Routes();
      var host = await mount(tester, routes);
      try {
        sdk.openStep(
          context: host,
          onClick: OnClick(action: Action.openStep, step: 1),
          currentContent: inline,
          campaign: Campaign.fromJson(campaignJson()),
        );
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
        expect(events.whereType<ContentCloseEvent>(), isEmpty);
        routes = _Routes();
        host = await mount(tester, routes);
        await present(tester, host, 'openStep');
        expect((routes.modalCount, count('/impression')), (1, 1));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      }
    });

    testWidgets(
      '$delivery keeps the live campaign guarded across an identity change',
      (tester) async {
        method = delivery;
        final routes = _Routes();
        final host = await mount(tester, routes);
        try {
          await present(tester, host, 'openStep');
          sdk.setUser('changed-$caseId', 'new-session');
          now = now.add(const Duration(seconds: 61));
          await present(tester, host, 'openStep');
          expect((routes.modalCount, count('/impression')), (1, 1));
          Navigator.of(host).pop();
          await settle(tester, closes: 1);
          await present(tester, host, 'openStep');
          expect((routes.modalCount, count('/impression')), (1, 2));
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      },
    );

    for (final close in [
      'control',
      'unmount',
      'remove',
      if (delivery != 'full_screen') 'barrier',
      if (delivery == 'bottom_sheet') 'swipe',
    ]) {
      testWidgets('$delivery releases attached campaign on $close', (
        tester,
      ) async {
        method = delivery;
        var routes = _Routes();
        var host = await mount(tester, routes);
        try {
          await present(tester, host, 'openStep');
          now = now.add(const Duration(seconds: 61));
          switch (close) {
            case 'control':
              await tester.tap(find.byType(GravityCloseButtonWidget));
            case 'swipe':
              await tester.fling(
                find.byType(BottomSheet),
                const Offset(0, 400),
                1000,
              );
            case 'remove':
              Navigator.of(host).removeRoute(routes.active.last);
            case 'barrier':
              await tester.tapAt(const Offset(5, 5));
            case 'unmount':
              await tester.pumpWidget(const SizedBox());
          }
          await settle(tester, closes: close == 'unmount' ? null : 1);
          if (close != 'unmount') {
            expect(count('/close'), 1);
            expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          } else {
            routes = _Routes();
            host = await mount(tester, routes);
          }
          await present(tester, host, 'openStep');
          expect(routes.modalCount, 1);
          expect(count('/impression'), 2);
          final expectedCloses = count('/close') + 1;
          Navigator.of(host).pop();
          await settle(tester, closes: expectedCloses);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await settle(tester);
        }
      });
    }
  }
}
