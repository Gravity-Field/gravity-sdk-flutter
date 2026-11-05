import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/data/outbox/outbox_dispatcher.dart';
import 'package:gravity_sdk/src/ui/widgets/close_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sdk = GravitySDK.instance;
  final events = <TrackingEvent>[];
  final requests = <String>[];
  late HttpServer server;
  late Completer<void> received;

  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    ErrorReporter.disableNetworkForTests = true;
    OutboxDispatcher.lifecycleObserverEnabled = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      if (!received.isCompleted) received.complete();
      await request.response.close();
    });
    await sdk.initialize(
      apiKey: 'key',
      section: 'section',
      gravityEventCallback: events.add,
    );
  });
  tearDownAll(() async {
    await server.close(force: true);
    sdk.gravityEventCallback = null;
    OutboxDispatcher.lifecycleObserverEnabled = true;
  });

  Future<BuildContext> show(
    WidgetTester tester,
    String method,
    String config, {
    bool form = false,
    bool buttonAction = false,
    bool paused = false,
  }) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      received = Completer<void>();
    });
    requests.clear();
    events.clear();
    final target = CampaignContent.fromJson({
      'contentId': 'target',
      'deliveryMethod': method,
      'contentType': 'native',
      'step': 1,
      'variables': {
        'frameUI': {
          'container': {'style': <String, dynamic>{}},
          'close': {
            if (buttonAction) 'onClick': {'action': 'close'},
          },
        },
        if (config != 'absent') 'onClose': {'action': 'close'},
        'elements': [
          {'type': 'text', 'text': 'target', 'style': <String, dynamic>{}},
          if (form)
            {
              'type': 'text-input',
              'attributeName': 'answer',
              'style': <String, dynamic>{},
            },
        ],
      },
      'events': [
        if (config != 'unmatched')
          {
            'type': 'close',
            'urls': ['http://127.0.0.1:${server.port}/close'],
          },
      ],
    });
    final inline = CampaignContent.fromJson({
      'contentId': 'inline',
      'deliveryMethod': 'inline',
      'contentType': 'native',
      'variables': <String, dynamic>{},
    });
    final campaign = Campaign(
      selector: null,
      payload: [
        CampaignVariation(
          campaignId: 'c',
          experienceId: 'e',
          variationId: 'v',
          decisionId: 'd',
          contents: [inline, target],
        ),
      ],
    );
    if (paused) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }
    await tester.runAsync(() async {
      sdk.openStep(
        context: host,
        onClick: OnClick(action: Action.openStep, step: 1),
        currentContent: inline,
        campaign: campaign,
      );
    });
    await tester.pumpAndSettle();
    return host;
  }

  for (final method in ['modal', 'bottom_sheet', 'full_screen']) {
    for (final config in ['configured', 'absent', 'unmatched']) {
      for (final form in [false, true]) {
        testWidgets('$method back close ($config, form=$form) notifies once', (
          tester,
        ) async {
          await show(tester, method, config, form: form);
          final beforeVisible = events
              .whereType<ContentVisibleImpressionEvent>()
              .length;
          final target = tester.element(find.text('target'));
          await tester.runAsync(() async {
            Navigator.of(target).pop();
          });
          await tester.pumpAndSettle();
          await tester.runAsync(() async {});
          await tester.pumpAndSettle();
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          expect(
            events.whereType<ContentVisibleImpressionEvent>(),
            hasLength(beforeVisible),
          );
          expect(find.text('target'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          if (config == 'configured') {
            await tester.runAsync(() => received.future);
          }
          expect(requests, config == 'configured' ? ['/close'] : isEmpty);
        });
      }
    }
    for (final config in ['configured', 'absent']) {
      for (final action in [false, true]) {
        testWidgets('$method X close (action=$action, $config) tracks once', (
          tester,
        ) async {
          await show(tester, method, config, buttonAction: action);
          final control = tester.widget<GravityCloseButtonWidget>(
            find.byType(GravityCloseButtonWidget),
          );
          await tester.runAsync(() async {
            if (control.close.onClick != null) {
              control.onClickCallback(control.close.onClick!);
            } else {
              control.onClose();
            }
          });
          await tester.pumpAndSettle();
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          await tester.pumpWidget(const SizedBox());
          if (config == 'configured' || action) {
            await tester.runAsync(() => received.future);
          }
          expect(
            requests,
            config == 'configured' || action ? ['/close'] : isEmpty,
          );
        });
      }
    }
  }

  testWidgets('a route dismissed before appearance does not track close', (
    tester,
  ) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await show(tester, 'modal', 'configured', paused: true);
    expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
    final target = tester.element(find.text('target'));
    await tester.runAsync(() async {
      Navigator.of(target).pop();
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(events.whereType<ContentCloseEvent>(), isEmpty);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bottom sheet swipe tracks one close', (tester) async {
    await show(tester, 'bottom_sheet', 'configured');
    await tester.fling(find.byType(BottomSheet), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
    expect(events.whereType<ContentCloseEvent>(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => received.future);
    expect(requests, ['/close']);
  });
}
