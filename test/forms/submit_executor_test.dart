import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action, Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/api/content_ids_response.dart';
import 'package:gravity_sdk/src/data/api/content_response.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/forms/submit_executor.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/event.dart';
import 'package:gravity_sdk/src/models/actions/form_action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/tracking_event.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/models/internal/delivery_type.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';
import 'package:gravity_sdk/src/models/internal/variables.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/logger.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';
import 'package:talker/talker.dart' as talker_lib;

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'submit-executor-test',
);

const _emptyEventResponse = CampaignIdsResponse(user: User());

class _SurveyFixture {
  const _SurveyFixture({
    required this.campaign,
    required this.content,
    required this.submit,
  });

  final Campaign campaign;
  final CampaignContent content;
  final OnClick submit;
}

class _SpyFormSession extends FormSession {
  _SpyFormSession()
    : super(pageContext: _pageContext, hasFormElements: true);

  final successfulReasons = <FormCloseReason>[];
  final attemptedReasons = <FormCloseReason>[];
  final operations = <String>[];
  var beginSubmitCalls = 0;
  var endSubmitCalls = 0;

  @override
  void beginSubmit() {
    beginSubmitCalls++;
    operations.add('beginSubmit');
    super.beginSubmit();
  }

  @override
  void endSubmit() {
    endSubmitCalls++;
    operations.add('endSubmit');
    super.endSubmit();
  }

  @override
  bool finish(
    FormCloseReason reason, {
    required CampaignContent content,
    required Campaign campaign,
  }) {
    attemptedReasons.add(reason);
    final won = super.finish(
      reason,
      content: content,
      campaign: campaign,
    );
    if (won) {
      successfulReasons.add(reason);
      operations.add('finish:${reason.name}');
    }
    return won;
  }
}

/// [stripMinLength] возвращает live-payload к виду «оптиональное поле без
/// минимума» — единственный способ покрыть контрактный кейс «пустое видимое
/// опциональное поле сериализуется как ""», который живой minLength запрещает.
_SurveyFixture _loadSurveyFixture({bool stripMinLength = false}) {
  final json = jsonDecode(
    File('test/fixtures/in_app_survey_payload.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  if (stripMinLength) {
    for (final rawCampaign in (json['data'] as List<dynamic>)) {
      final campaign = rawCampaign as Map<String, dynamic>;
      for (final rawVariation in (campaign['payload'] as List<dynamic>)) {
        final variation = rawVariation as Map<String, dynamic>;
        for (final rawContent in (variation['contents'] as List<dynamic>)) {
          final content = rawContent as Map<String, dynamic>;
          final variables = content['variables'] as Map<String, dynamic>;
          for (final rawElement in (variables['elements'] as List<dynamic>)) {
            (rawElement as Map<String, dynamic>).remove('minLength');
          }
        }
      }
    }
  }
  final response = ContentResponse.fromJson(json);
  final campaign = response.data.single;
  final content = campaign.payload.single.contents.single;
  final submit = content.variables.elements!
      .singleWhere((element) => element.onClick?.action == Action.submitForm)
      .onClick!;
  return _SurveyFixture(
    campaign: campaign,
    content: content,
    submit: submit,
  );
}

Future<BuildContext> _pumpFormRoute(WidgetTester tester) async {
  late BuildContext hostContext;
  late BuildContext formContext;

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

  unawaited(
    showModalBottomSheet<void>(
      context: hostContext,
      builder: (context) {
        formContext = context;
        return const SizedBox(
          key: ValueKey('form-route'),
          height: 120,
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return formContext;
}

CampaignContent _contentWithUnknownTrackingEvent() => CampaignContent(
  contentId: 'unknown-action-content',
  templateSystemName: null,
  deliveryMethod: DeliveryMethod.modal,
  contentType: 'native',
  variables: Variables(elements: const []),
  products: null,
  events: [Event(type: Action.unknown, urls: const [])],
);

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
  });

  setUp(() {
    GravityRepo.eventOverride = null;
    GravityRepo.triggerEventUrlsObserver = null;
    GravitySDK.instance.gravityEventCallback = null;
    talker.cleanHistory();
  });

  tearDown(() {
    GravityRepo.eventOverride = null;
    GravityRepo.triggerEventUrlsObserver = null;
    GravitySDK.instance.gravityEventCallback = null;
  });

  testWidgets(
    'empty visible required input aborts before event and effects',
    (tester) async {
      final fixture = _loadSurveyFixture();
      final session = _SpyFormSession();
      final context = await _pumpFormRoute(tester);
      var eventCalls = 0;
      final callbacks = <TrackingEvent>[];
      GravityRepo.eventOverride = (events, pageContext) async {
        eventCalls++;
        return _emptyEventResponse;
      };
      GravitySDK.instance.gravityEventCallback = callbacks.add;

      await SubmitExecutor().execute(
        onClick: fixture.submit,
        content: fixture.content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pump();

      expect(eventCalls, 0);
      expect(callbacks, isEmpty);
      expect(session.successfulReasons, isEmpty);
      expect(session.beginSubmitCalls, 0);
      expect(session.endSubmitCalls, 0);
      expect(find.byKey(const ValueKey('form-route')), findsOneWidget);
    },
  );

  testWidgets(
    'visible input below minLength aborts before event and effects',
    (tester) async {
      final fixture = _loadSurveyFixture();
      final submit = OnClick.fromJson({
        'action': 'submit_form',
        'event': {'type': 'in-app-review-v1', 'name': 'In-app review'},
        'default': {
          'do': [
            {'effect': 'close'},
          ],
        },
      });
      final content = CampaignContent(
        contentId: 'min-length-content',
        templateSystemName: null,
        deliveryMethod: DeliveryMethod.modal,
        contentType: 'native',
        variables: Variables(
          elements: [
            Element(
              type: ElementType.textInput,
              style: null,
              attributeName: 'feedback',
              minLength: 3,
            ),
          ],
        ),
        products: null,
        events: null,
      );
      final session = _SpyFormSession()..setValue('feedback', 'ab');
      final context = await _pumpFormRoute(tester);
      var eventCalls = 0;
      GravityRepo.eventOverride = (events, pageContext) async {
        eventCalls++;
        return _emptyEventResponse;
      };

      await SubmitExecutor().execute(
        onClick: submit,
        content: content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pump();

      expect(eventCalls, 0);
      expect(session.beginSubmitCalls, 0);
      expect(session.successfulReasons, isEmpty);
      expect(find.byKey(const ValueKey('form-route')), findsOneWidget);
    },
  );

  testWidgets(
    'follow_url effect passes its webview type into FollowUrlEvent',
    (tester) async {
      final fixture = _loadSurveyFixture();
      final submit = OnClick.fromJson({
        'action': 'submit_form',
        'event': {'type': 'in-app-review-v1', 'name': 'In-app review'},
        'default': {
          'do': [
            {'effect': 'follow_url', 'type': 'webview', 'url': 'https://example.com/faq'},
          ],
        },
      });
      final content = CampaignContent(
        contentId: 'follow-url-effect-content',
        templateSystemName: null,
        deliveryMethod: DeliveryMethod.modal,
        contentType: 'native',
        variables: Variables(elements: const []),
        products: null,
        events: null,
      );
      final session = _SpyFormSession();
      final context = await _pumpFormRoute(tester);
      final callbacks = <TrackingEvent>[];
      GravityRepo.eventOverride = (events, pageContext) async => _emptyEventResponse;
      GravitySDK.instance.gravityEventCallback = callbacks.add;

      await SubmitExecutor().execute(
        onClick: submit,
        content: content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pumpAndSettle();

      final event = callbacks.whereType<FollowUrlEvent>().single;
      expect(event.url, 'https://example.com/faq');
      expect(event.type, FollowUrlType.webview);
      expect(session.successfulReasons, [FormCloseReason.submitted]);
    },
  );

  testWidgets(
    '5 star submit snapshots rating, closes, then emits FollowUrlEvent',
    (tester) async {
      final fixture = _loadSurveyFixture();
      final session = _SpyFormSession()..setValue('rating', 5);
      final context = await _pumpFormRoute(tester);
      final customEvents = <CustomEvent>[];
      final callbacks = <TrackingEvent>[];
      GravityRepo.eventOverride = (events, pageContext) async {
        customEvents.addAll(events.whereType<CustomEvent>());
        return _emptyEventResponse;
      };
      GravitySDK.instance.gravityEventCallback = (event) {
        session.operations.add('callback:${event.runtimeType}');
        callbacks.add(event);
      };

      await SubmitExecutor().execute(
        onClick: fixture.submit,
        content: fixture.content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pumpAndSettle();

      expect(customEvents, hasLength(1));
      expect(customEvents.single.customProps, {'rating': '5'});
      expect(callbacks, hasLength(1));
      expect(callbacks.single, isA<FollowUrlEvent>());
      expect(
        (callbacks.single as FollowUrlEvent).type,
        FollowUrlType.browser,
      );
      expect(
        (callbacks.single as FollowUrlEvent).url,
        startsWith('https://play.google.com/store/apps/details'),
      );
      expect(session.successfulReasons, [FormCloseReason.submitted]);
      expect(session.beginSubmitCalls, 1);
      expect(session.endSubmitCalls, 1);
      expect(
        session.operations.indexOf('finish:submitted'),
        lessThan(session.operations.indexOf('callback:FollowUrlEvent')),
      );
      expect(find.byKey(const ValueKey('form-route')), findsNothing);
    },
  );

  testWidgets(
    '1 star submit includes visible empty feedback and uses default close',
    (tester) async {
      final fixture = _loadSurveyFixture(stripMinLength: true);
      final session = _SpyFormSession()..setValue('rating', 1);
      final context = await _pumpFormRoute(tester);
      final customEvents = <CustomEvent>[];
      GravityRepo.eventOverride = (events, pageContext) async {
        customEvents.addAll(events.whereType<CustomEvent>());
        return _emptyEventResponse;
      };

      await SubmitExecutor().execute(
        onClick: fixture.submit,
        content: fixture.content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pumpAndSettle();

      expect(customEvents.single.customProps, {
        'rating': '1',
        'feedback': '',
      });
      expect(session.successfulReasons, [FormCloseReason.submitted]);
      expect(find.byKey(const ValueKey('form-route')), findsNothing);
    },
  );

  testWidgets(
    '2 star text changed to 5 omits hidden feedback from props and route',
    (tester) async {
      final fixture = _loadSurveyFixture();
      final session = _SpyFormSession()
        ..setValue('rating', 2)
        ..setValue('feedback', 'Needs improvement')
        ..setValue('rating', 5);
      final context = await _pumpFormRoute(tester);
      final customEvents = <CustomEvent>[];
      final callbacks = <TrackingEvent>[];
      GravityRepo.eventOverride = (events, pageContext) async {
        customEvents.addAll(events.whereType<CustomEvent>());
        return _emptyEventResponse;
      };
      GravitySDK.instance.gravityEventCallback = callbacks.add;

      await SubmitExecutor().execute(
        onClick: fixture.submit,
        content: fixture.content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pumpAndSettle();

      expect(session.valueOf('feedback'), 'Needs improvement');
      expect(customEvents.single.customProps, {'rating': '5'});
      expect(callbacks.single, isA<FollowUrlEvent>());
      expect(session.successfulReasons, [FormCloseReason.submitted]);
    },
  );

  testWidgets('event network failure never throws and still executes effects', (
    tester,
  ) async {
    final fixture = _loadSurveyFixture();
    final session = _SpyFormSession()
      ..setValue('rating', 1)
      ..setValue('feedback', 'Отличный сервис, спасибо');
    final context = await _pumpFormRoute(tester);
    GravityRepo.eventOverride = (events, pageContext) {
      return Future<CampaignIdsResponse>.error(StateError('offline'));
    };

    await expectLater(
      SubmitExecutor().execute(
        onClick: fixture.submit,
        content: fixture.content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      ),
      completes,
    );
    await tester.pumpAndSettle();

    expect(session.successfulReasons, [FormCloseReason.submitted]);
    expect(session.isSubmitting, isFalse);
    expect(find.byKey(const ValueKey('form-route')), findsNothing);
  });

  testWidgets(
    'terminal effect drops its tail and records a real warning',
    (tester) async {
      final fixture = _loadSurveyFixture();
      final session = _SpyFormSession()..setValue('rating', 5);
      final context = await _pumpFormRoute(tester);
      final callbacks = <TrackingEvent>[];
      GravityRepo.eventOverride = (events, pageContext) async {
        return _emptyEventResponse;
      };
      GravitySDK.instance.gravityEventCallback = callbacks.add;
      final submitWithTerminalTail = OnClick(
        action: Action.submitForm,
        closeOnClick: false,
        event: const FormEventSpec(type: 'survey-v1', name: 'Survey'),
        routes: const [],
        defaultRoute: const FormRoute(
          when: null,
          effects: [
            FormEffect(effect: FormEffectType.close),
            FormEffect(
              effect: FormEffectType.openUrl,
              url: 'https://must-not-open.example',
            ),
          ],
        ),
      );

      await SubmitExecutor().execute(
        onClick: submitWithTerminalTail,
        content: fixture.content,
        campaign: fixture.campaign,
        session: session,
        context: context,
      );
      await tester.pumpAndSettle();

      expect(callbacks, isEmpty);
      expect(session.successfulReasons, [FormCloseReason.submitted]);
      expect(
        talker.history.where(
          (entry) =>
              entry.logLevel == talker_lib.LogLevel.warning &&
              entry.message?.contains('terminal') == true &&
              entry.message?.contains('ignored') == true,
        ),
        isNotEmpty,
      );
    },
  );

  testWidgets('second submit is a no-op while the first is submitting', (
    tester,
  ) async {
    final fixture = _loadSurveyFixture();
    final session = _SpyFormSession()
      ..setValue('rating', 1)
      ..setValue('feedback', 'Отличный сервис, спасибо');
    final context = await _pumpFormRoute(tester);
    final executor = SubmitExecutor();
    var eventCalls = 0;
    Future<void>? reentrantAttempt;
    GravityRepo.eventOverride = (events, pageContext) {
      eventCalls++;
      if (eventCalls == 1) {
        reentrantAttempt = executor.execute(
          onClick: fixture.submit,
          content: fixture.content,
          campaign: fixture.campaign,
          session: session,
          context: context,
        );
      }
      return Future.value(_emptyEventResponse);
    };

    await executor.execute(
      onClick: fixture.submit,
      content: fixture.content,
      campaign: fixture.campaign,
      session: session,
      context: context,
    );
    await reentrantAttempt;
    await tester.pumpAndSettle();

    expect(eventCalls, 1);
    expect(session.beginSubmitCalls, 1);
    expect(session.endSubmitCalls, 1);
    expect(session.successfulReasons, [FormCloseReason.submitted]);
  });

  testWidgets('unknown action is guarded before matching tracking events', (
    tester,
  ) async {
    final fixture = _loadSurveyFixture();
    final context = await _pumpFormRoute(tester);
    var trackingCalls = 0;
    GravityRepo.triggerEventUrlsObserver = (urls) => trackingCalls++;

    OnClickHandler(
      content: _contentWithUnknownTrackingEvent(),
      campaign: fixture.campaign,
    ).handeOnClick(OnClick(action: Action.unknown), context);
    await tester.pump();

    expect(trackingCalls, 0);
  });
}
