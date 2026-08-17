import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/api/content_ids_response.dart';
import 'package:gravity_sdk/src/data/api/content_response.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/tracking_event.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_content.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'in-app-review-flow-test',
);

const _emptyEventResponse = CampaignIdsResponse(user: User());

const _handleKey = ValueKey('gravityDragHandle');

class _ReviewCampaign {
  const _ReviewCampaign({required this.campaign, required this.root});

  final Campaign campaign;
  final CampaignContent root;
}

class _SpyFormSession extends FormSession {
  _SpyFormSession() : super(pageContext: _pageContext, hasFormElements: true);

  final successfulReasons = <FormCloseReason>[];

  @override
  bool finish(
    FormCloseReason reason, {
    required CampaignContent content,
    required Campaign campaign,
  }) {
    final won = super.finish(reason, content: content, campaign: campaign);
    if (won) successfulReasons.add(reason);
    return won;
  }
}

_ReviewCampaign _loadReviewCampaign({String? storeUrlOnFifthStar}) {
  final decoded =
      jsonDecode(
            File('test/fixtures/in_app_review_payload.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  if (storeUrlOnFifthStar != null) {
    for (final rawCampaign in (decoded['data'] as List<dynamic>)) {
      final campaign = rawCampaign as Map<String, dynamic>;
      for (final rawVariation in (campaign['payload'] as List<dynamic>)) {
        final variation = rawVariation as Map<String, dynamic>;
        for (final rawContent in (variation['contents'] as List<dynamic>)) {
          final content = rawContent as Map<String, dynamic>;
          final variables = content['variables'] as Map<String, dynamic>;
          for (final rawElement in (variables['elements'] as List<dynamic>)) {
            final element = rawElement as Map<String, dynamic>;
            if (element['type'] != 'option-select') continue;
            final fifth = (element['options'] as List<dynamic>).last as Map<String, dynamic>;
            (fifth['onClick'] as Map<String, dynamic>)['default'] = {
              'do': [
                {
                  'effect': 'follow_url',
                  'url': storeUrlOnFifthStar,
                  'type': 'browser',
                },
              ],
            };
          }
        }
      }
    }
  }

  final response = ContentResponse.fromJson(decoded);
  final campaign = response.data.single;
  return _ReviewCampaign(
    campaign: campaign,
    root: campaign.payload.single.contents.firstWhere(
      (content) => content.step == null,
    ),
  );
}

Future<void> _showReviewBottomSheet({
  required WidgetTester tester,
  required _ReviewCampaign review,
  required _SpyFormSession session,
}) async {
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

  final route = showModalBottomSheet<void>(
    isScrollControlled: true,
    useSafeArea: true,
    context: hostContext,
    builder: (context) => BottomSheetContent(
      content: review.root,
      campaign: review.campaign,
      session: session,
    ),
  );
  unawaited(
    route.whenComplete(() {
      if (!session.consumeStepTransition()) {
        session.finish(
          FormCloseReason.dismiss,
          content: review.root,
          campaign: review.campaign,
        );
      }
    }),
  );
  await tester.pumpAndSettle();
}

void _captureCustomEvents(List<CustomEvent> target) {
  GravityRepo.eventOverride = (events, pageContext) async {
    target.addAll(events.whereType<CustomEvent>());
    return _emptyEventResponse;
  };
}

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    GravityRepo.eventOverride = null;
    GravityRepo.triggerEventUrlsObserver = null;
    GravitySDK.instance.gravityEventCallback = null;
  });

  tearDown(() {
    GravityRepo.eventOverride = null;
    GravityRepo.triggerEventUrlsObserver = null;
    GravitySDK.instance.gravityEventCallback = null;
  });

  testWidgets(
    'fifth star tap instantly submits and opens the positive thank-you step',
    (tester) async {
      final review = _loadReviewCampaign();
      final session = _SpyFormSession();
      final customEvents = <CustomEvent>[];
      final callbacks = <TrackingEvent>[];
      _captureCustomEvents(customEvents);
      GravitySDK.instance.gravityEventCallback = callbacks.add;
      await _showReviewBottomSheet(
        tester: tester,
        review: review,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.star).at(4));
      await tester.pumpAndSettle();

      // The submit happened on the star tap itself — no submit button press.
      expect(customEvents, hasLength(1));
      expect(customEvents.single.type, 'in-app-review-v1');
      expect(customEvents.single.customProps, {
        'rating': '5',
        'campaignId': 'campaign-review-1',
        'experienceId': 'experience-review-1',
      });

      // The positive thank-you step replaced the form, with its drag handle.
      expect(find.text('ОЦЕНИТЬ ПРИЛОЖЕНИЕ'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byKey(_handleKey), findsOneWidget);

      await tester.tap(find.text('ОЦЕНИТЬ ПРИЛОЖЕНИЕ'));
      await tester.pumpAndSettle();

      final followUrlEvents = callbacks.whereType<FollowUrlEvent>().toList();
      expect(followUrlEvents, hasLength(1));
      expect(followUrlEvents.single.url, startsWith('https://play.google.com/'));
      expect(followUrlEvents.single.type, FollowUrlType.browser);
      expect(find.byType(BottomSheetContent), findsNothing);
    },
  );

  testWidgets(
    'ticket scenario: fifth star tap emits the event and opens the store at once',
    (tester) async {
      const storeUrl = 'https://store-url-for-current-experience';
      final review = _loadReviewCampaign(storeUrlOnFifthStar: storeUrl);
      final session = _SpyFormSession();
      final customEvents = <CustomEvent>[];
      final callbacks = <TrackingEvent>[];
      _captureCustomEvents(customEvents);
      GravitySDK.instance.gravityEventCallback = callbacks.add;
      await _showReviewBottomSheet(
        tester: tester,
        review: review,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.star).at(4));
      await tester.pumpAndSettle();

      expect(customEvents.single.type, 'in-app-review-v1');
      expect(customEvents.single.customProps!['rating'], '5');
      final followUrlEvents = callbacks.whereType<FollowUrlEvent>().toList();
      expect(followUrlEvents, hasLength(1));
      expect(followUrlEvents.single.url, storeUrl);
      expect(followUrlEvents.single.type, FollowUrlType.browser);
      // Никакого промежуточного шага: форма закрылась, стор открыт хостом.
      expect(find.byType(BottomSheetContent), findsNothing);
      expect(session.successfulReasons, [FormCloseReason.submitted]);
    },
  );

  testWidgets(
    'four stars keep the feedback path: counterless textarea, submit, negative thank-you',
    (tester) async {
      final review = _loadReviewCampaign();
      final session = _SpyFormSession();
      final customEvents = <CustomEvent>[];
      _captureCustomEvents(customEvents);
      await _showReviewBottomSheet(
        tester: tester,
        review: review,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.star).at(3));
      await tester.pumpAndSettle();

      // The star tap alone runs no action — only option five carries one.
      expect(customEvents, isEmpty);
      expect(find.byType(BottomSheetContent), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Что можно улучшить?'), findsOneWidget);
      // showCounter: false hides the system maxLength counter.
      expect(find.text('0/250'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Хочу больше размеров');
      await tester.pump();
      expect(find.text('20/250'), findsNothing);

      await tester.tap(find.text('ОТПРАВИТЬ'));
      await tester.pumpAndSettle();

      expect(customEvents, hasLength(1));
      expect(customEvents.single.customProps, {
        'rating': '4',
        'feedback': 'Хочу больше размеров',
        'campaignId': 'campaign-review-1',
        'experienceId': 'experience-review-1',
      });

      // The negative thank-you step with the drag handle replaced the form.
      expect(find.text('ХОРОШО'), findsOneWidget);
      expect(find.byKey(_handleKey), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('ХОРОШО'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheetContent), findsNothing);
      expect(session.successfulReasons, [FormCloseReason.explicitClose]);
      expect(customEvents, hasLength(1));
    },
  );

  testWidgets('empty feedback submits: no minLength gate in the review flow', (
    tester,
  ) async {
    final review = _loadReviewCampaign();
    final session = _SpyFormSession();
    final customEvents = <CustomEvent>[];
    _captureCustomEvents(customEvents);
    await _showReviewBottomSheet(
      tester: tester,
      review: review,
      session: session,
    );

    await tester.tap(find.byIcon(Icons.star).first);
    await tester.pumpAndSettle();

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ОТПРАВИТЬ'),
    );
    expect(
      submitButton.onPressed,
      isNotNull,
      reason: 'Optional feedback must not gate the submit button',
    );

    await tester.tap(find.text('ОТПРАВИТЬ'));
    await tester.pumpAndSettle();

    expect(customEvents.single.customProps, {
      'rating': '1',
      'feedback': '',
      'campaignId': 'campaign-review-1',
      'experienceId': 'experience-review-1',
    });
    expect(find.text('ХОРОШО'), findsOneWidget);
  });
}
