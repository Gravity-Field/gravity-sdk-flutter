import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/src/utils/modal_impression.dart';
import 'package:gravity_sdk/src/ui/widgets/modal_appearance.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_content.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/full_screen/full_screen_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/modal/modal_content.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:visibility_detector/visibility_detector.dart';

Campaign campaign({
  String format = 'modal',
  String close = 'close',
  bool step = false,
}) => Campaign.fromJson({
  'payload': [
    {
      'campaignId': 'fast-close',
      'experienceId': 'e',
      'variationId': 'v',
      'decisionId': 'd',
      'contents': [
        {
          'contentId': 'window',
          'deliveryMethod': format,
          'contentType': 'native',
          'variables': {
            'frameUI': {
              'container': {
                'style': {'backgroundColor': '#ffffffff'},
              },
              'close': {
                'onClick': {'action': close},
                'style': {
                  'positioned': {'right': 8, 'top': 0},
                },
              },
            },
            'elements': [
              {
                'type': 'text',
                'text': 'Visible content',
                'style': {'fontSize': 20},
              },
              {
                'type': 'button',
                'text': step ? 'Next' : 'Не сейчас',
                'style': {
                  'textStyle': {'fontSize': 16},
                },
                'onClick': step
                    ? {'action': 'open_step', 'step': 2}
                    : {'action': 'cancel'},
              },
            ],
          },
          'events': [
            {
              'type': 'visible_impression',
              'urls': [
                'https://example.test/engagement?type=WRIMP&user=original',
              ],
            },
          ],
        },
        if (step)
          {
            'contentId': 'step-two',
            'step': 2,
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
                  'text': 'Second step',
                  'style': {'fontSize': 20},
                },
              ],
            },
            'events': [
              {
                'type': 'visible_impression',
                'urls': ['https://example.test/second?type=WRIMP'],
              },
            ],
          },
      ],
    },
  ],
});

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
  });
  testWidgets(
    'first painted modal frame fires WRIMP without custom action before 100ms close',
    (tester) async {
      final c = campaign();
      final sent = <String>[];
      GravityRepo.triggerEventUrlsObserver = sent.addAll;
      addTearDown(() => GravityRepo.triggerEventUrlsObserver = null);
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 500,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ModalContent(
            content: c.payload.first.contents.first,
            campaign: c,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(sent, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(sent, hasLength(1));
    },
  );

  for (final format in ['modal', 'bottom_sheet', 'full_screen']) {
    for (final close in [
      'x',
      'button',
      'back',
      if (format == 'bottom_sheet') 'swipe',
    ]) {
      testWidgets('$format $close at 100–400ms emits one impression', (
        tester,
      ) async {
        final c = campaign(format: format);
        var events = 0;
        final opening = ModalImpression(
          onVisible: () async {
            events++;
          },
        );
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
        final content = c.payload.first.contents.first;
        if (format == 'modal') {
          showDialog<void>(
            context: host,
            builder: (_) => ModalContent(
              content: content,
              campaign: c,
              impression: opening,
            ),
          );
        } else if (format == 'bottom_sheet') {
          showModalBottomSheet<void>(
            context: host,
            builder: (_) => BottomSheetContent(
              content: content,
              campaign: c,
              impression: opening,
            ),
          );
        } else {
          Navigator.of(host).push<void>(
            MaterialPageRoute(
              builder: (_) => FullScreenContent(
                content: content,
                campaign: c,
                impression: opening,
              ),
            ),
          );
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          events,
          1,
          reason: 'content appeared while opening animation was running',
        );
        if (close == 'x') {
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.byIcon(Icons.close));
        } else if (close == 'button') {
          await tester.tap(find.text('Не сейчас'));
        } else if (close == 'swipe') {
          await tester.fling(
            find.text('Visible content'),
            const Offset(0, 600),
            3000,
          );
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.text('Visible content'), findsNothing);
        expect(events, 1);
      });
    }
  }

  testWidgets(
    'OPEN_STEP preserves one opening and does not emit another WRIMP',
    (tester) async {
      final c = campaign(format: 'bottom_sheet', step: true);
      var events = 0;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
      );
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
      showModalBottomSheet<void>(
        context: host,
        builder: (_) => BottomSheetContent(
          content: c.payload.first.contents.first,
          campaign: c,
          impression: opening,
        ),
      );
      await tester.pumpAndSettle();
      expect(events, 1);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second step'), findsOneWidget);
      expect(events, 1);
      Navigator.of(host).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('an already painted inactive window resumes and closes via Back without a detector frame', (
    tester,
  ) async {
    var events = 0;
    final opening = ModalImpression(
      onVisible: () async {
        events++;
      },
    );
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final c = campaign();
    showDialog<void>(
      context: host,
      builder: (_) => ModalContent(content: c.payload.first.contents.first, campaign: c, impression: opening),
    );
    await tester.pumpAndSettle();
    expect(events, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // No pump between resume and Back: an embedder need not produce a frame.
    await tester.binding.handlePopRoute();
    expect(events, 1);
    await tester.pumpAndSettle();
    expect(events, 1);
  });

  testWidgets(
    'user or screen invalidated before first frame cancels without WRIMP',
    (tester) async {
      var events = 0;
      var releases = 0;
      var valid = true;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
        onUnshownClose: () => releases++,
        isValid: () => valid,
      );
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
      final c = campaign();
      showDialog<void>(
        context: host,
        builder: (_) => ModalContent(
          content: c.payload.first.contents.first,
          campaign: c,
          impression: opening,
        ),
      );
      valid = false;
      await tester.pumpAndSettle();
      expect(events, 0);
      expect(releases, 1);
      expect(find.byType(ModalContent), findsNothing);
    },
  );

  testWidgets(
    'inactive before appearance waits for resumed without cancelling',
    (tester) async {
      var events = 0;
      var releases = 0;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
        onUnshownClose: () => releases++,
      );
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
      final c = campaign();
      showDialog<void>(
        context: host,
        builder: (_) => ModalContent(
          content: c.payload.first.contents.first,
          campaign: c,
          impression: opening,
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(releases, 0);
      expect(events, 0);
      expect(find.byType(ModalContent), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(events, 1);
      Navigator.of(host).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Back at zero opacity never confirms a modal impression', (
    tester,
  ) async {
    var events = 0;
    final opening = ModalImpression(
      onVisible: () async {
        events++;
      },
    );
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
    final c = campaign();
    showDialog<void>(
      context: host,
      builder: (_) => ModalContent(
        content: c.payload.first.contents.first,
        campaign: c,
        impression: opening,
      ),
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(events, 0);
    expect(opening.closedBeforeAppearance, isTrue);
  });

  testWidgets(
    'backgrounding before appearance cancels the window and cannot show it untracked on resume',
    (tester) async {
      var events = 0;
      var releases = 0;
      final opening = ModalImpression(
        onVisible: () async {
          events++;
        },
        onUnshownClose: () => releases++,
      );
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
      final c = campaign();
      showDialog<void>(
        context: host,
        builder: (_) => ModalContent(
          content: c.payload.first.contents.first,
          campaign: c,
          impression: opening,
        ),
      );
      await tester
          .pump(); // Dialog is created, but its transition is at opacity 0.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(events, 0);
      expect(releases, 1);
      expect(find.byType(ModalContent), findsNothing);
    },
  );

  testWidgets(
    'unpainted, offscreen or background content releases without an impression',
    (tester) async {
      for (final mode in ['offstage', 'zero', 'offscreen', 'background']) {
        var events = 0;
        var releases = 0;
        final opening = ModalImpression(
          onVisible: () async {
            events++;
          },
          onUnshownClose: () => releases++,
        );
        if (mode == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        }
        Widget child = ModalAppearance(
          impression: opening,
          child: const SizedBox(width: 100, height: 100),
        );
        if (mode == 'offstage') child = Offstage(child: child);
        if (mode == 'zero') child = SizedBox.shrink(child: child);
        if (mode == 'offscreen') {
          child = Transform.translate(
            offset: const Offset(2000, 2000),
            child: child,
          );
        }
        await tester.pumpWidget(MaterialApp(home: Center(child: child)));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        expect(events, 0, reason: mode);
        expect(releases, 1, reason: mode);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    },
  );
}
