import 'dart:convert';

import 'package:flutter/material.dart' hide Action, Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/api/content_ids_response.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/forms/submit_executor.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/form_action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/external/trigger_event.dart';
import 'package:gravity_sdk/src/models/external/user.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/utils/logger.dart';

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'submitted-flag-test',
);

Campaign _campaign(List<Map<String, dynamic>> elements) => Campaign.fromJson(
  jsonDecode(
        jsonEncode({
          'selector': 'submitted-flag',
          'payload': [
            {
              'campaignId': 'c1',
              'experienceId': 'e1',
              'variationId': 'v1',
              'decisionId': 'd1',
              'contents': [
                {
                  'contentId': 'root',
                  'deliveryMethod': 'modal',
                  'contentType': 'native',
                  'variables': {'elements': elements},
                },
              ],
            },
          ],
        }),
      )
      as Map<String, dynamic>,
);

Map<String, dynamic> _rating() => {
  'type': 'option-select',
  'attributeName': 'rating',
  'displayFormat': 'rating',
  'selectMode': 'single',
  'required': true,
  'options': [for (var i = 1; i <= 5; i++) {'value': i}],
  'style': <String, dynamic>{},
};

void main() {
  setUpAll(() {
    ErrorReporter.disableNetworkForTests = true;
    LoggerManager.instance.initDefault();
  });

  setUp(() {
    GravityRepo.eventOverride = (events, pageContext) async =>
        const CampaignIdsResponse(user: User());
  });

  tearDown(() {
    GravityRepo.eventOverride = null;
  });

  test('effect "none" parses and is not terminal', () {
    final onClick = OnClick.fromJson(
      jsonDecode(
            jsonEncode({
              'action': 'submit_form',
              'closeOnClick': false,
              'event': {'type': 'review-v1', 'name': 'Submitted'},
              'default': {
                'do': [
                  {'effect': 'none'},
                ],
              },
            }),
          )
          as Map<String, dynamic>,
    );

    expect(onClick.action, Action.submitForm);
    expect(
      onClick.defaultRoute!.effects.single.effect,
      FormEffectType.none,
    );
  });

  testWidgets('a submitted form exposes the reserved «submitted» attribute', (
    tester,
  ) async {
    final campaign = _campaign([_rating()]);
    final content = campaign.payload.single.contents.single;
    final session = FormSession(
      pageContext: _pageContext,
      hasFormElements: true,
    )..setValue('rating', 4);
    final onClick = OnClick(
      action: Action.submitForm,
      closeOnClick: false,
      event: const FormEventSpec(type: 'review-v1', name: 'Submitted'),
      defaultRoute: const FormRoute(
        when: null,
        effects: [FormEffect(effect: FormEffectType.none)],
      ),
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(session.valueOf('submitted'), isNull);

    await SubmitExecutor().execute(
      onClick: onClick,
      content: content,
      campaign: campaign,
      session: session,
      context: context,
    );

    // Форма осталась открытой, но состояние знает, что отправка прошла —
    // на это может смотреть visibleWhen, чтобы показать «спасибо».
    expect(session.valueOf('submitted'), 'true');
    expect(session.isFinished, isFalse);
    expect(session.isSubmitting, isFalse);
  });

  testWidgets('the reserved attribute never reaches the event props', (
    tester,
  ) async {
    final campaign = _campaign([_rating()]);
    final content = campaign.payload.single.contents.single;
    final session = FormSession(
      pageContext: _pageContext,
      hasFormElements: true,
    )..setValue('rating', 5);
    final props = <String, String>{};
    GravityRepo.eventOverride = (events, pageContext) async {
      props.addAll(events.whereType<CustomEvent>().single.customProps!);
      return const CampaignIdsResponse(user: User());
    };
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await SubmitExecutor().execute(
      onClick: OnClick(
        action: Action.submitForm,
        closeOnClick: false,
        event: const FormEventSpec(type: 'review-v1', name: 'Submitted'),
        defaultRoute: const FormRoute(
          when: null,
          effects: [FormEffect(effect: FormEffectType.none)],
        ),
      ),
      content: content,
      campaign: campaign,
      session: session,
      context: context,
    );
    await tester.pumpAndSettle();

    expect(props.containsKey('submitted'), isFalse);
    expect(props['rating'], '5');
  });

  testWidgets('an invalid form neither submits nor marks itself', (
    tester,
  ) async {
    final campaign = _campaign([_rating()]);
    final content = campaign.payload.single.contents.single;
    final session = FormSession(
      pageContext: _pageContext,
      hasFormElements: true,
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await SubmitExecutor().execute(
      onClick: OnClick(
        action: Action.submitForm,
        closeOnClick: false,
        event: const FormEventSpec(type: 'review-v1', name: 'Submitted'),
        defaultRoute: const FormRoute(
          when: null,
          effects: [FormEffect(effect: FormEffectType.none)],
        ),
      ),
      content: content,
      campaign: campaign,
      session: session,
      context: context,
    );

    expect(session.valueOf('submitted'), isNull);
  });
}
