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
  location: 'in-app-form-flow-test',
);

const _emptyEventResponse = CampaignIdsResponse(user: User());

class _LiveSurvey {
  const _LiveSurvey({required this.campaign, required this.content});

  final Campaign campaign;
  final CampaignContent content;
}

class _SpyFormSession extends FormSession {
  _SpyFormSession()
    : super(pageContext: _pageContext, hasFormElements: true);

  final successfulReasons = <FormCloseReason>[];

  @override
  bool finish(
    FormCloseReason reason, {
    required CampaignContent content,
    required Campaign campaign,
  }) {
    final won = super.finish(
      reason,
      content: content,
      campaign: campaign,
    );
    if (won) successfulReasons.add(reason);
    return won;
  }
}

_LiveSurvey _loadLiveSurvey() {
  final decoded = jsonDecode(
    File('test/fixtures/in_app_survey_payload.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  // The fixture is production payload. Only tracking transport is neutralized
  // in this decoded test copy; the fixture itself and all form data stay live.
  for (final rawCampaign in (decoded['data'] as List<dynamic>)) {
    final campaign = rawCampaign as Map<String, dynamic>;
    for (final rawVariation in (campaign['payload'] as List<dynamic>)) {
      final variation = rawVariation as Map<String, dynamic>;
      for (final rawContent in (variation['contents'] as List<dynamic>)) {
        final content = rawContent as Map<String, dynamic>;
        for (final rawEvent
            in (content['events'] as List<dynamic>? ?? const <dynamic>[])) {
          (rawEvent as Map<String, dynamic>)['urls'] = <String>[];
        }
      }
    }
  }

  final response = ContentResponse.fromJson(decoded);
  final campaign = response.data.single;
  return _LiveSurvey(
    campaign: campaign,
    content: campaign.payload.single.contents.single,
  );
}

Future<void> _showLiveBottomSheet({
  required WidgetTester tester,
  required _LiveSurvey survey,
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

  final frameUi = survey.content.variables.frameUI!;
  final container = frameUi.container;
  final route = showModalBottomSheet<void>(
    backgroundColor: container.style?.backgroundColor,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(container.style?.cornerRadius ?? 0),
        topRight: Radius.circular(container.style?.cornerRadius ?? 0),
      ),
    ),
    context: hostContext,
    builder: (context) => BottomSheetContent(
      content: survey.content,
      campaign: survey.campaign,
      session: session,
    ),
  );
  unawaited(
    route.whenComplete(() {
      if (!session.consumeStepTransition()) {
        session.finish(
          FormCloseReason.dismiss,
          content: survey.content,
          campaign: survey.campaign,
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
    'initial live survey shows rating and not-now but hides submit and feedback',
    (tester) async {
      final survey = _loadLiveSurvey();
      final session = _SpyFormSession();

      await _showLiveBottomSheet(
        tester: tester,
        survey: survey,
        session: session,
      );

      expect(find.byIcon(Icons.star), findsNWidgets(5));
      expect(find.text('Не сейчас'), findsOneWidget);
      expect(find.text('Отправить'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    '1 star feedback submits visible props through default close route',
    (tester) async {
      final survey = _loadLiveSurvey();
      final session = _SpyFormSession();
      final customEvents = <CustomEvent>[];
      _captureCustomEvents(customEvents);
      await _showLiveBottomSheet(
        tester: tester,
        survey: survey,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.star).first);
      await tester.pumpAndSettle();

      expect(find.text('Не сейчас'), findsNothing);
      expect(find.text('Отправить'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Не хватает деталей');
      // Кадр на перекладку: пока поле было пустым, кнопка была задизейблена
      // из-за minLength — тап по старому билду ушёл бы в null onPressed.
      await tester.pump();
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(customEvents, hasLength(1));
      expect(customEvents.single.customProps, {
        'rating': '1',
        'feedback': 'Не хватает деталей',
      });
      expect(find.byType(BottomSheetContent), findsNothing);
      expect(session.successfulReasons, [FormCloseReason.submitted]);
    },
  );

  testWidgets(
    '3 star empty feedback with minLength keeps submit disabled from open',
    (tester) async {
      final survey = _loadLiveSurvey();
      final session = _SpyFormSession();
      final customEvents = <CustomEvent>[];
      _captureCustomEvents(customEvents);
      await _showLiveBottomSheet(
        tester: tester,
        survey: survey,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.star).at(2));
      await tester.pumpAndSettle();

      expect(find.text('Минимум 15 символов'), findsOneWidget);
      FilledButton submitButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Отправить'),
      );
      // The screenshot scenario: field just appeared, nothing typed yet —
      // the button must already be disabled, not only after the first char.
      expect(submitButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Мало');
      await tester.pumpAndSettle();
      expect(submitButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Теперь достаточно длинно');
      await tester.pumpAndSettle();
      expect(submitButton().onPressed, isNotNull);

      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(customEvents.single.customProps, {
        'rating': '3',
        'feedback': 'Теперь достаточно длинно',
      });
      expect(session.successfulReasons, [FormCloseReason.submitted]);
    },
  );

  testWidgets(
    '2 star feedback changed to 5 uses high-rating route without feedback',
    (tester) async {
      final survey = _loadLiveSurvey();
      final session = _SpyFormSession();
      final customEvents = <CustomEvent>[];
      final callbacks = <TrackingEvent>[];
      _captureCustomEvents(customEvents);
      GravitySDK.instance.gravityEventCallback = callbacks.add;
      await _showLiveBottomSheet(
        tester: tester,
        survey: survey,
        session: session,
      );

      await tester.tap(find.byIcon(Icons.star).at(1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Сначала было непонятно');
      await tester.tap(find.byIcon(Icons.star).at(4));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Отправить'), findsOneWidget);

      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(session.valueOf('feedback'), 'Сначала было непонятно');
      expect(customEvents.single.customProps, {'rating': '5'});
      // The real sheet also emits its visible-impression host callback, so
      // only the follow-url slice is pinned here.
      final followUrlEvents = callbacks.whereType<FollowUrlEvent>().toList();
      expect(followUrlEvents, hasLength(1));
      expect(
        followUrlEvents.single.url,
        startsWith('https://play.google.com/store/apps/details'),
      );
      // Form open_url effects carry no `type` — the contract default is
      // browser, so the host sends the store URL to the system handler.
      expect(followUrlEvents.single.type, FollowUrlType.browser);
      expect(find.byType(BottomSheetContent), findsNothing);
      expect(session.successfulReasons, [FormCloseReason.submitted]);
    },
  );

  testWidgets('swipe dismiss sends no submit event and finishes dismiss', (
    tester,
  ) async {
    final survey = _loadLiveSurvey();
    final session = _SpyFormSession();
    final customEvents = <CustomEvent>[];
    _captureCustomEvents(customEvents);
    await _showLiveBottomSheet(
      tester: tester,
      survey: survey,
      session: session,
    );

    await tester.drag(find.byType(BottomSheet), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(customEvents, isEmpty);
    expect(find.byType(BottomSheetContent), findsNothing);
    expect(session.successfulReasons, [FormCloseReason.dismiss]);
  });

  testWidgets('not-now sends no submit event and finishes explicitClose', (
    tester,
  ) async {
    final survey = _loadLiveSurvey();
    final session = _SpyFormSession();
    final customEvents = <CustomEvent>[];
    _captureCustomEvents(customEvents);
    await _showLiveBottomSheet(
      tester: tester,
      survey: survey,
      session: session,
    );

    await tester.tap(find.text('Не сейчас'));
    await tester.pumpAndSettle();

    expect(customEvents, isEmpty);
    expect(find.byType(BottomSheetContent), findsNothing);
    expect(session.successfulReasons, [FormCloseReason.explicitClose]);
  });
}
