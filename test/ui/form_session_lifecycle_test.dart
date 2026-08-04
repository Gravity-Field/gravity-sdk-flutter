import 'dart:convert';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/tracking_event.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_content.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'form-session-lifecycle-test',
);

class _SpyFormSession extends FormSession {
  _SpyFormSession() : super(pageContext: _pageContext, hasFormElements: true);

  final successfulReasons = <FormCloseReason>[];
  final attemptedReasons = <FormCloseReason>[];

  @override
  bool finish(
    FormCloseReason reason, {
    required CampaignContent content,
    required Campaign campaign,
  }) {
    attemptedReasons.add(reason);
    final finished = super.finish(
      reason,
      content: content,
      campaign: campaign,
    );
    if (finished) successfulReasons.add(reason);
    return finished;
  }
}

// Inline map literals infer Map<dynamic, dynamic> for nested empty maps,
// which the generated parsers reject; the json round-trip in [_campaign]
// mirrors what Dio's jsonDecode produces in production.
Map<String, dynamic> _content(
  String id, {
  int? step,
  String deliveryMethod = 'bottom_sheet',
  List<Map<String, dynamic>> elements = const [],
  bool hasCloseIcon = false,
  bool trackClose = false,
}) => {
  'contentId': id,
  'deliveryMethod': deliveryMethod,
  'contentType': 'native',
  'variables': {
    'frameUI': {
      'container': {
        'style': {
          'backgroundColor': '#ffffffff',
          'cornerRadius': 12,
          'padding': {'left': 16, 'right': 16, 'top': 16, 'bottom': 16},
        },
      },
      if (hasCloseIcon)
        'close': {
          'onClick': {'action': 'close'},
          'style': {
            'positioned': {'right': 8, 'top': 8},
          },
        },
    },
    'elements': elements,
    if (trackClose) 'onClose': {'action': 'close'},
  },
  if (trackClose)
    'events': [
      {'type': 'close', 'urls': <String>[]},
    ],
  if (step != null) 'step': step,
};

Campaign _campaign(List<Map<String, dynamic>> contents) => Campaign.fromJson(
  jsonDecode(
        jsonEncode({
          'selector': 'form-session-lifecycle',
          'payload': [
            {
              'campaignId': 'campaign-1',
              'experienceId': 'experience-1',
              'variationId': 'variation-1',
              'decisionId': 'decision-1',
              'contents': contents,
            },
          ],
        }),
      )
      as Map<String, dynamic>,
);

CampaignContent _contentById(Campaign campaign, String id) => campaign.payload
    .expand((variation) => variation.contents)
    .firstWhere((content) => content.contentId == id);

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            hostContext = context;
            return const Text('Host route');
          },
        ),
      ),
    ),
  );
  return hostContext;
}

Future<void> _showStepFromInline({
  required WidgetTester tester,
  required BuildContext context,
  required Campaign campaign,
  required CampaignContent currentContent,
  required int step,
  required _SpyFormSession session,
}) async {
  GravitySDK.instance.openStep(
    context: context,
    onClick: OnClick(action: Action.openStep, step: step),
    currentContent: currentContent,
    campaign: campaign,
    session: session,
  );
  await tester.pumpAndSettle();

  expect(find.byType(BottomSheetContent), findsOneWidget);
  expect(
    session.consumeStepTransition(),
    isTrue,
    reason: 'The inline source has no route-completion hook in this harness',
  );
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    GravitySDK.instance.gravityEventCallback = null;
    GravityRepo.triggerEventUrlsObserver = null;
  });

  tearDown(() {
    GravitySDK.instance.gravityEventCallback = null;
    GravityRepo.triggerEventUrlsObserver = null;
  });

  testWidgets('bottom-sheet swipe dismiss finishes once with dismiss', (
    tester,
  ) async {
    final campaign = _campaign([
      _content('root', deliveryMethod: 'inline'),
      _content(
        'step-1',
        step: 1,
        trackClose: true,
        elements: [
          {
            'type': 'text-input',
            'attributeName': 'feedback',
            'style': {},
          },
        ],
      ),
    ]);
    final session = _SpyFormSession();
    var closeEvents = 0;
    var closeTrackingCalls = 0;
    GravitySDK.instance.gravityEventCallback = (event) {
      if (event is ContentCloseEvent) closeEvents++;
    };
    GravityRepo.triggerEventUrlsObserver = (_) => closeTrackingCalls++;
    final context = await _pumpHost(tester);

    await _showStepFromInline(
      tester: tester,
      context: context,
      campaign: campaign,
      currentContent: _contentById(campaign, 'root'),
      step: 1,
      session: session,
    );

    await tester.drag(
      find.byType(BottomSheet),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheetContent), findsNothing);
    expect(session.successfulReasons, [FormCloseReason.dismiss]);
    expect(session.attemptedReasons, [FormCloseReason.dismiss]);
    expect(closeEvents, 1);
    expect(closeTrackingCalls, 1);
  });

  testWidgets(
    'close icon finishes explicitClose before pop and completion stays idempotent',
    (tester) async {
      final campaign = _campaign([
        _content('root', deliveryMethod: 'inline'),
        _content(
          'step-1',
          step: 1,
          hasCloseIcon: true,
          trackClose: true,
          elements: [
            {
              'type': 'text-input',
              'attributeName': 'feedback',
              'style': {},
            },
          ],
        ),
      ]);
      final session = _SpyFormSession();
      var closeEvents = 0;
      var closeTrackingCalls = 0;
      GravitySDK.instance.gravityEventCallback = (event) {
        if (event is ContentCloseEvent) closeEvents++;
      };
      GravityRepo.triggerEventUrlsObserver = (_) => closeTrackingCalls++;
      final context = await _pumpHost(tester);

      await _showStepFromInline(
        tester: tester,
        context: context,
        campaign: campaign,
        currentContent: _contentById(campaign, 'root'),
        step: 1,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.close));

      // The route-completion dismiss attempt lands as a microtask right after
      // the pop; only the reason that won the race must ever succeed.
      expect(session.successfulReasons, [FormCloseReason.explicitClose]);
      expect(session.attemptedReasons.first, FormCloseReason.explicitClose);
      expect(closeEvents, 1);
      expect(closeTrackingCalls, 1);
      expect(find.byType(BottomSheetContent), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(BottomSheetContent), findsNothing);
      expect(session.successfulReasons, [FormCloseReason.explicitClose]);
      expect(
        session.attemptedReasons,
        [FormCloseReason.explicitClose, FormCloseReason.dismiss],
      );
      expect(closeEvents, 1);
      expect(closeTrackingCalls, 1);
      expect(find.text('Host route'), findsOneWidget);
    },
  );

  for (final action in ['close', 'cancel']) {
    testWidgets(
      '$action button finishes explicitClose before its single pop',
      (tester) async {
        final campaign = _campaign([
          _content('root', deliveryMethod: 'inline'),
          _content(
            'step-1',
            step: 1,
            trackClose: true,
            elements: [
              {
                'type': 'text-input',
                'attributeName': 'feedback',
                'style': {},
              },
              {
                'type': 'button',
                'text': 'Explicit $action',
                'style': {},
                'onClick': {'action': action},
              },
            ],
          ),
        ]);
        final session = _SpyFormSession();
        var closeEvents = 0;
        var closeTrackingCalls = 0;
        GravitySDK.instance.gravityEventCallback = (event) {
          if (event is ContentCloseEvent) closeEvents++;
        };
        GravityRepo.triggerEventUrlsObserver = (_) => closeTrackingCalls++;
        final context = await _pumpHost(tester);

        await _showStepFromInline(
          tester: tester,
          context: context,
          campaign: campaign,
          currentContent: _contentById(campaign, 'root'),
          step: 1,
          session: session,
        );

        await tester.tap(find.text('Explicit $action'));

        // The route-completion dismiss attempt lands as a microtask right
        // after the pop; only the reason that won the race must ever succeed.
        expect(session.successfulReasons, [FormCloseReason.explicitClose]);
        expect(session.attemptedReasons.first, FormCloseReason.explicitClose);
        expect(closeEvents, 1);
        expect(closeTrackingCalls, 1);
        expect(find.byType(BottomSheetContent), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.byType(BottomSheetContent), findsNothing);
        expect(session.successfulReasons, [FormCloseReason.explicitClose]);
        expect(
          session.attemptedReasons,
          [FormCloseReason.explicitClose, FormCloseReason.dismiss],
        );
        expect(closeEvents, 1);
        expect(closeTrackingCalls, 1);
        expect(find.text('Host route'), findsOneWidget);
      },
    );
  }

  testWidgets('openStep preserves one session and state across two steps', (
    tester,
  ) async {
    final campaign = _campaign([
      _content('root', deliveryMethod: 'inline'),
      _content(
        'step-1',
        step: 1,
        elements: [
          {
            'type': 'option-select',
            'attributeName': 'rating',
            'displayFormat': 'rating',
            'selectMode': 'single',
            'options': [
              {'value': 1},
              {'value': 2},
              {'value': 3},
              {'value': 4},
              {'value': 5},
            ],
            'style': {},
          },
          {
            'type': 'button',
            'text': 'Next step',
            'style': {},
            'onClick': {'action': 'open_step', 'step': 2},
          },
        ],
      ),
      _content(
        'step-2',
        step: 2,
        elements: [
          {
            'type': 'text',
            'text': 'Rating survived',
            'style': {},
            'visibleWhen': {
              'attributeName': 'rating',
              'operator': 'equal',
              'value': 4,
            },
          },
        ],
      ),
    ]);
    final session = _SpyFormSession();
    final context = await _pumpHost(tester);

    await _showStepFromInline(
      tester: tester,
      context: context,
      campaign: campaign,
      currentContent: _contentById(campaign, 'root'),
      step: 1,
      session: session,
    );

    await tester.tap(find.byIcon(Icons.star).at(3));
    await tester.pump();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();

    final secondStep = tester.widget<BottomSheetContent>(
      find.byType(BottomSheetContent),
    );
    expect(secondStep.content.contentId, 'step-2');
    expect(secondStep.session, same(session));
    expect(session.valueOf('rating'), 4);
    expect(find.text('Rating survived'), findsOneWidget);
    expect(session.successfulReasons, isEmpty);
    expect(session.attemptedReasons, isEmpty);
    expect(session.consumeStepTransition(), isFalse);

    Navigator.of(tester.element(find.byType(BottomSheetContent))).pop();
    await tester.pumpAndSettle();
    expect(session.successfulReasons, [FormCloseReason.dismiss]);
    expect(session.attemptedReasons, [FormCloseReason.dismiss]);
  });

  testWidgets('missing step does not poison the next dismiss', (tester) async {
    final campaign = _campaign([
      _content('root', deliveryMethod: 'inline'),
      _content(
        'step-1',
        step: 1,
        elements: [
          {
            'type': 'text-input',
            'attributeName': 'feedback',
            'style': {},
          },
        ],
      ),
    ]);
    final session = _SpyFormSession();
    final context = await _pumpHost(tester);
    final root = _contentById(campaign, 'root');

    GravitySDK.instance.openStep(
      context: context,
      onClick: OnClick(action: Action.openStep, step: 404),
      currentContent: root,
      campaign: campaign,
      session: session,
    );
    await tester.pump();

    await _showStepFromInline(
      tester: tester,
      context: context,
      campaign: campaign,
      currentContent: root,
      step: 1,
      session: session,
    );

    await tester.drag(
      find.byType(BottomSheet),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();

    expect(session.successfulReasons, [FormCloseReason.dismiss]);
  });
}
