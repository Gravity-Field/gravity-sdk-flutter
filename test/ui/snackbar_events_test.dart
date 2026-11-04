import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:gravity_sdk/src/utils/modal_impression.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:gravity_sdk/src/utils/identity_version.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _closeImageUrl = 'https://images.example.test/close.png';

Campaign campaign({
  bool closeButton = false,
  bool containerClose = false,
  bool impressionHook = true,
  int? closeTextIndex,
  int? closeImageIndex,
  bool onClose = true,
}) => Campaign.fromJson(
  jsonDecode(
        jsonEncode({
          'payload': [
            {
              'campaignId': 'snackbar-events',
              'experienceId': 'e',
              'variationId': 'v',
              'decisionId': 'd',
              'contents': [
                {
                  'contentId': 'snackbar',
                  'deliveryMethod': 'snackbar',
                  'contentType': 'native',
                  'variables': {
                    'frameUI': {
                      'container': {
                        if (containerClose) 'onClick': {'action': 'close'},
                        'style': {
                          'padding': {'top': 16, 'bottom': 16},
                        },
                      },
                    },
                    'elements': [
                      if (closeImageIndex != null)
                        for (var index = 0; index <= closeImageIndex; index++)
                          {
                            'type': 'image',
                            'src': _closeImageUrl,
                            'style': {
                              'size': {'width': 24, 'height': 24},
                            },
                            if (index == closeImageIndex)
                              'onClick': {
                                'action': 'close',
                                'closeOnClick': true,
                              },
                          },
                      {
                        'type': 'text',
                        'text': 'Notification',
                        if (closeTextIndex == 0) 'onClick': {'action': 'close'},
                        'style': {'fontSize': 20},
                      },
                      if (closeTextIndex == 1)
                        {'type': 'text', 'text': 'Second notification', 'style': {'fontSize': 20}, 'onClick': {'action': 'close'}},
                      if (closeButton)
                        {
                          'type': 'button',
                          'text': 'Dismiss',
                          'style': {'fontSize': 20},
                          'onClick': {'action': 'close', 'closeOnClick': true},
                        },
                    ],
                    if (impressionHook) 'onImpression': {'action': 'impression'},
                    if (onClose) 'onClose': {'action': 'close'},
                  },
                  'events': [
                    {'type': 'impression', 'urls': []},
                    {
                      'type': 'close',
                      'urls': !closeButton && !containerClose && closeImageIndex == null && closeTextIndex == null
                          ? []
                          : ['https://tracking.example.test/close'],
                    },
                  ],
                },
              ],
            },
          ],
        }),
      )
      as Map<String, dynamic>,
);

void main() {
  final events = <Object>[];
  final originalInterval = VisibilityDetectorController.instance.updateInterval;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.configure(LogLevel.none);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    events.clear();
    GravitySDK.instance.gravityEventCallback = events.add;
  });
  tearDown(() {
    GravitySDK.instance.gravityEventCallback = null;
    VisibilityDetectorController.instance.updateInterval = originalInterval;
  });

  for (final template in [TemplateSystemName.snackbar1, TemplateSystemName.snackbar2]) {
    for (final earlyClose in [false, true]) {
      testWidgets('S1a first positive paint owns impression ($template, earlyClose=$earlyClose)', (tester) async {
        final data = campaign(containerClose: true);
        var released = 0;
        var visible = 0;
        final opening = ModalImpression(onVisible: () async { visible++; }, onUnshownClose: () { released++; });
        late BuildContext host;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        })));
        SnackBarContent.show(context: host, snackBarContent: SnackBarContent.getSnackBar(
          template: template, content: data.payload.first.contents.first, campaign: data,
        ), durationSeconds: earlyClose ? 1 : 10, impression: opening);
        await tester.pump();
        await tester.pump();
        final fade = tester.widget<FadeTransition>(find.ancestor(of: find.text('Notification'), matching: find.byType(FadeTransition)).first);
        expect(fade.opacity.value, 0);
        expect(events.whereType<ContentImpressionEvent>(), isEmpty, reason: 'the attached frame at zero opacity is not an impression');
        if (earlyClose) {
          // Let the auto-close timer run without drawing a positive frame.
          await tester.pump(const Duration(seconds: 1), EnginePhase.build);
          await tester.pumpAndSettle();
          expect(find.text('Notification'), findsNothing);
          expect(events.whereType<ContentImpressionEvent>(), isEmpty);
          expect(events.whereType<ContentCloseEvent>(), isEmpty);
        } else {
          await tester.pump(const Duration(milliseconds: 1));
          expect(fade.opacity.value, greaterThan(0));
          expect(events.whereType<ContentImpressionEvent>(), hasLength(1));
          await tester.pump(const Duration(milliseconds: 1));
          expect(events.whereType<ContentImpressionEvent>(), hasLength(1));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 11));
        expect(released, 1);
        expect(visible, 0);
      });
    }
  }

  for (final template in [TemplateSystemName.snackbar1, TemplateSystemName.snackbar2]) {
    testWidgets('S7 focus after the last paint restarts visibility without another draw ($template)', (tester) async {
      final data = campaign();
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      })));
      SnackBarContent.show(context: host, snackBarContent: SnackBarContent.getSnackBar(
        template: template, content: data.payload.first.contents.first, campaign: data,
      ), durationSeconds: 10);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 2), EnginePhase.build);
      expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
      tester.binding.handleViewFocusChanged(ui.ViewFocusEvent(
        viewId: tester.view.viewId, state: ui.ViewFocusState.focused, direction: ui.ViewFocusDirection.undefined,
      ));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Run timers/build only: there is no new layout/paint/geometry report.
      await tester.pump(const Duration(seconds: 1), EnginePhase.build);
      expect(events.whereType<ContentVisibleImpressionEvent>(), hasLength(1));
      expect(events.whereType<ContentImpressionEvent>(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });
  }

  testWidgets('background interrupts the one second visibility interval', (
    tester,
  ) async {
    final data = campaign();
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
    SnackBarContent.show(
      context: host,
      snackBarContent: SnackBarContent.getSnackBar(
        template: TemplateSystemName.snackbar1,
        content: data.payload.first.contents.first,
        campaign: data,
      ),
      durationSeconds: 10,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(events.whereType<ContentImpressionEvent>(), hasLength(1));
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump();
    expect(events.whereType<ContentImpressionEvent>(), hasLength(1), reason: 'layout does not repeat impression');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 100));
    expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 999));
    expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(events.whereType<ContentVisibleImpressionEvent>(), hasLength(1));
    expect(events.whereType<ContentImpressionEvent>(), hasLength(1), reason: 'resume does not repeat impression');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets(
    'unmount before visibility releases the opening without tracking close',
    (tester) async {
      var releases = 0;
      var visible = 0;
      final opening = ModalImpression(
        onVisible: () async {
          visible++;
        },
        onUnshownClose: () => releases++,
      );
      final data = campaign();
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
      SnackBarContent.show(
        context: host,
        snackBarContent: SnackBarContent.getSnackBar(
          template: TemplateSystemName.snackbar1,
          content: data.payload.first.contents.first,
          campaign: data,
        ),
        durationSeconds: 4,
        impression: opening,
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(releases, 1);
      expect(visible, 0);
      expect(events.whereType<ContentCloseEvent>(), isEmpty);
    },
  );

  for (final cancellation in ['unmounted', 'invalid']) {
    testWidgets('cancels $cancellation context before overlay insertion', (
      tester,
    ) async {
      var valid = true;
      var releases = 0;
      final opening = ModalImpression(
        isValid: () => valid,
        onVisible: () async {},
        onUnshownClose: () => releases++,
      );
      final data = campaign();
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
      SnackBarContent.show(
        context: host,
        snackBarContent: SnackBarContent.getSnackBar(
          template: TemplateSystemName.snackbar1,
          content: data.payload.first.contents.first,
          campaign: data,
        ),
        durationSeconds: 4,
        impression: opening,
      );
      if (cancellation == 'unmounted') {
        await tester.pumpWidget(const SizedBox());
      } else {
        valid = false;
        await tester.pump();
      }
      await tester.pump();
      expect(releases, 1);
      expect(events, isEmpty);
      expect(find.text('Notification'), findsNothing);
    });
  }

  for (final missing in ['Overlay', 'MediaQuery']) {
    testWidgets('releases opening when host has no $missing', (tester) async {
      var releases = 0;
      final opening = ModalImpression(
        onVisible: () async {},
        onUnshownClose: () => releases++,
      );
      final data = campaign();
      late BuildContext host;
      final builder = Builder(
        builder: (context) {
          host = context;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        RawView(
          view: tester.view,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: missing == 'Overlay'
                ? MediaQuery(data: const MediaQueryData(), child: builder)
                : Overlay(
                    initialEntries: [OverlayEntry(builder: (_) => builder)],
                  ),
          ),
        ),
        wrapWithView: false,
      );
      SnackBarContent.show(
        context: host,
        snackBarContent: SnackBarContent.getSnackBar(
          template: TemplateSystemName.snackbar1,
          content: data.payload.first.contents.first,
          campaign: data,
        ),
        durationSeconds: 4,
        impression: opening,
      );
      await tester.pump();
      expect(releases, 1);
      expect(tester.takeException(), isNull);
      expect(events, isEmpty);
    });
  }

  for (final imageIndex in [null, 0, 1]) {
    for (final onClose in [false, true]) {
      testWidgets(
        'close ${imageIndex == null ? 'button' : 'image $imageIndex'} tracks once with onClose=$onClose',
        (tester) async {
          final sent = <List<String>>[];
          GravityRepo.triggerEventUrlsObserver = sent.add;
          addTearDown(() => GravityRepo.triggerEventUrlsObserver = null);
          if (imageIndex != null) {
            // Seed the network image cache; external image loading is not under test.
            final recorder = ui.PictureRecorder();
            ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
            final picture = recorder.endRecording();
            final image = await tester.runAsync(() => picture.toImage(1, 1));
            picture.dispose();
            PaintingBinding.instance.imageCache.putIfAbsent(
              const NetworkImage(_closeImageUrl),
              () => OneFrameImageStreamCompleter(
                Future.value(ImageInfo(image: image!)),
              ),
            );
            addTearDown(() => PaintingBinding.instance.imageCache.clear());
          }
          final data = campaign(
            closeButton: imageIndex == null,
            closeImageIndex: imageIndex,
            onClose: onClose,
          );
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
          SnackBarContent.show(
            context: host,
            snackBarContent: SnackBarContent.getSnackBar(
              template: imageIndex == null
                  ? TemplateSystemName.snackbar2
                  : TemplateSystemName.snackbar1,
              content: data.payload.first.contents.first,
              campaign: data,
            ),
            durationSeconds: 4,
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          sent.clear();
          await tester.tap(
            imageIndex == null
                ? find.text('Dismiss')
                : find.byType(GravityImageWidget).at(imageIndex),
          );
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 5));
          expect(sent, [
            ['https://tracking.example.test/close'],
          ]);
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
        },
      );
    }
  }

  for (final template in [
    TemplateSystemName.snackbar1,
    TemplateSystemName.snackbar2,
  ]) {
    for (final close in ['timer', 'swipe']) {
      testWidgets(
        '$template sends impression, delayed visibility and one close by $close',
        (tester) async {
          final data = campaign();
          final content = data.payload.first.contents.first;
          final snackbar = SnackBarContent.getSnackBar(
            template: template,
            content: content,
            campaign: data,
          );
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
          void show() => SnackBarContent.show(
            context: host,
            snackBarContent: snackbar,
            durationSeconds: 4,
          );
          show();
          await tester.pump();
          await tester.pump();
          expect(events.whereType<ContentImpressionEvent>(), isEmpty);
          await tester.pump(const Duration(milliseconds: 300));
          expect(events.whereType<ContentImpressionEvent>(), hasLength(1));
          await tester.pump(const Duration(milliseconds: 999));
          expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
          await tester.pump(const Duration(milliseconds: 1));
          expect(
            events.whereType<ContentVisibleImpressionEvent>(),
            hasLength(1),
          );
          if (close == 'swipe') {
            await tester.fling(
              find.text('Notification'),
              const Offset(0, -100),
              1000,
            );
          } else {
            await tester.pump(const Duration(seconds: 4));
          }
          await tester.pumpAndSettle();
          expect(find.text('Notification'), findsNothing);
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          await tester.pump(const Duration(seconds: 5));
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          // Reusing the content object must create fresh per-show flags.
          show();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Notification'), findsOneWidget);
          expect(events.whereType<ContentImpressionEvent>(), hasLength(2));
          expect(
            events.whereType<ContentVisibleImpressionEvent>(),
            hasLength(2),
          );
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(events.whereType<ContentCloseEvent>(), hasLength(2));
        },
      );
    }
    testWidgets('$template quick swipe does not force a visible impression', (
      tester,
    ) async {
      final data = campaign();
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
      SnackBarContent.show(
        context: host,
        snackBarContent: SnackBarContent.getSnackBar(
          template: template,
          content: data.payload.first.contents.first,
          campaign: data,
        ),
        durationSeconds: 4,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.fling(
        find.text('Notification'),
        const Offset(0, -100),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
      expect(events.whereType<ContentCloseEvent>(), hasLength(1));
    });
  }
  for (final template in [TemplateSystemName.snackbar1, TemplateSystemName.snackbar2]) {
    for (final onClose in [false, true]) {
      testWidgets('$template container close dismisses and tracks once with onClose=$onClose', (tester) async {
        final sent = <List<String>>[];
        GravityRepo.triggerEventUrlsObserver = sent.add;
        addTearDown(() => GravityRepo.triggerEventUrlsObserver = null);
        final data = campaign(containerClose: true, onClose: onClose);
        late BuildContext host;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        })));
        SnackBarContent.show(
          context: host,
          snackBarContent: SnackBarContent.getSnackBar(
            template: template,
            content: data.payload.first.contents.first,
            campaign: data,
          ),
          durationSeconds: 4,
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        sent.clear();
        await tester.tap(find.text('Notification'));
        await tester.pumpAndSettle();
        final shownAfterTap = find.text('Notification').evaluate().isNotEmpty;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(sent, [['https://tracking.example.test/close']], reason: 'tap and later timer cannot send two close URLs');
        expect(shownAfterTap, isFalse, reason: 'container close must remove the snackbar before its auto-close timer');
        expect(events.whereType<ContentCloseEvent>(), hasLength(1));
        expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
      });
    }
  }

  for (final template in [TemplateSystemName.snackbar1, TemplateSystemName.snackbar2]) {
    testWidgets('S6 no close without impression when onImpression is absent ($template)', (tester) async {
      final data = campaign(containerClose: true, impressionHook: false);
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      })));
      SnackBarContent.show(context: host, snackBarContent: SnackBarContent.getSnackBar(
        template: template, content: data.payload.first.contents.first, campaign: data,
      ), durationSeconds: 4);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Notification'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(events.whereType<ContentCloseEvent>(), hasLength(1));
      expect(events.whereType<ContentImpressionEvent>(), hasLength(1), reason: 'the physical appearance callback does not depend on a tracking hook');
    });
  }

  for (final template in [TemplateSystemName.snackbar1, TemplateSystemName.snackbar2]) {
    for (final index in [0, 1]) {
      for (final onClose in [false, true]) {
        testWidgets('xflu-1 text $index close dismisses once ($template, onClose=$onClose)', (tester) async {
          final sent = <List<String>>[];
          GravityRepo.triggerEventUrlsObserver = sent.add;
          addTearDown(() => GravityRepo.triggerEventUrlsObserver = null);
          final data = campaign(closeTextIndex: index, onClose: onClose);
          late BuildContext host;
          await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
            host = context;
            return const Scaffold();
          })));
          SnackBarContent.show(context: host, snackBarContent: SnackBarContent.getSnackBar(
            template: template, content: data.payload.first.contents.first, campaign: data,
          ), durationSeconds: 4);
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          sent.clear();
          await tester.tap(find.text(index == 0 ? 'Notification' : 'Second notification'));
          await tester.pumpAndSettle();
          final shownAfterTap = find.text('Notification').evaluate().isNotEmpty;
          final closesAfterTap = events.whereType<ContentCloseEvent>().length;
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(shownAfterTap, isFalse);
          expect(closesAfterTap, 1);
          expect(events.whereType<ContentCloseEvent>(), hasLength(1));
          expect(sent, [['https://tracking.example.test/close']]);
          expect(events.whereType<ContentVisibleImpressionEvent>(), isEmpty);
        });
      }
    }
  }

  // S3: automatic dismissal tracks only onClose; a close control owns its close URL.
  for (final onClose in [false, true]) {
    for (final path in ['timer', 'swipe', 'button', 'background']) {
      testWidgets('agreed close contract: $path with onClose=$onClose', (tester) async {
        final sent = <List<String>>[];
        GravityRepo.triggerEventUrlsObserver = sent.add;
        addTearDown(() => GravityRepo.triggerEventUrlsObserver = null);
        final data = campaign(closeButton: true, onClose: onClose);
        late BuildContext host;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        })));
        SnackBarContent.show(
          context: host,
          snackBarContent: SnackBarContent.getSnackBar(
            template: TemplateSystemName.snackbar2,
            content: data.payload.first.contents.first,
            campaign: data,
          ),
          durationSeconds: 4,
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        sent.clear();
        switch (path) {
          case 'timer':
            await tester.pump(const Duration(seconds: 5));
          case 'swipe':
            await tester.fling(find.text('Notification'), const Offset(0, -100), 1000);
          case 'button':
            await tester.tap(find.text('Dismiss'));
          case 'background':
            tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
            await tester.pump(const Duration(milliseconds: 100));
            expect(sent, isEmpty, reason: 'background alone does not close');
            expect(find.text('Notification'), findsOneWidget);
            await tester.pump(const Duration(seconds: 5));
            tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }
        await tester.pumpAndSettle();
        final expectedUrls = onClose || path == 'button'
            ? [['https://tracking.example.test/close']]
            : <List<String>>[];
        expect(sent, expectedUrls);
        expect(events.whereType<ContentCloseEvent>(), hasLength(1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        expect(sent, hasLength(expectedUrls.length));
      });
    }
  }

  for (final path in ['timer', 'swipe', 'button', 'background']) {
    testWidgets('early $path dismissal releases the snackbar reservation once', (tester) async {
      final gate = InAppPresentationGate.instance;
      final request = gate.beginRequest('/early-$path', IdentityVersion.current, newScreen: true);
      final reservation = gate.reserve('early-$path', 'campaign', request)!;
      var releases = 0;
      var visible = 0;
      final opening = ModalImpression(
        isValid: () => gate.owns(reservation),
        onVisible: () async { visible++; },
        onUnshownClose: () {
          releases++;
          gate.cancel(reservation);
        },
      );
      final data = campaign(closeButton: true, onClose: false);
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const Scaffold();
      })));
      SnackBarContent.show(
        context: host,
        snackBarContent: SnackBarContent.getSnackBar(
          template: TemplateSystemName.snackbar2,
          content: data.payload.first.contents.first,
          campaign: data,
        ),
        durationSeconds: 1,
        impression: opening,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      switch (path) {
        case 'timer':
          await tester.pump(const Duration(seconds: 2));
        case 'swipe':
          await tester.fling(find.text('Notification'), const Offset(0, -100), 1000);
        case 'button':
          await tester.tap(find.text('Dismiss'));
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          await tester.pump(const Duration(seconds: 2));
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      await tester.pumpAndSettle();
      expect(releases, 1);
      expect(visible, 0);
      expect(gate.owns(reservation), isFalse);
      final replacement = gate.reserve('early-$path', 'campaign', request);
      expect(replacement, isNotNull);
      if (replacement != null) gate.cancel(replacement);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(releases, 1, reason: 'dispose cannot release a second time');
    });
  }
  testWidgets('legacy snackbar buildContent VoidCallback remains source compatible', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      host = context;
      return const Scaffold();
    })));
    SnackBarContent.show(context: host, snackBarContent: _LegacySnackBar(), durationSeconds: 4);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Legacy dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Legacy dismiss'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

}

class _LegacySnackBar extends SnackBarContent {
  @override
  Widget buildContent(BuildContext context, {VoidCallback? onDismiss}) =>
      TextButton(onPressed: onDismiss, child: const Text('Legacy dismiss'));
}
