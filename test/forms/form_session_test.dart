import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/models/internal/campaign_variation.dart';
import 'package:gravity_sdk/src/models/internal/condition.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';

const _pageContext = PageContext(
  type: ContextType.other,
  data: [],
  location: 'form-session-test',
);

CampaignContent _content({
  List<Map<String, dynamic>> elements = const [],
}) =>
    CampaignContent.fromJson({
      'contentId': 'content-1',
      'deliveryMethod': 'modal',
      'contentType': 'native',
      'variables': {'elements': elements},
    });

Campaign _campaign(CampaignContent content) => Campaign(
      selector: null,
      payload: [
        CampaignVariation(
          campaignId: 'campaign-1',
          experienceId: 'experience-1',
          variationId: 'variation-1',
          decisionId: 'decision-1',
          contents: [content],
        ),
      ],
    );

FormSession _session({bool hasFormElements = false}) => FormSession(
      pageContext: _pageContext,
      hasFormElements: hasFormElements,
    );

void main() {
  group('FormSession state', () {
    test('preserves typed number and string values', () {
      final session = _session();

      session.setValue('rating', 4);
      session.setValue('feedback', 'Very useful');

      expect(session.valueOf('rating'), isA<num>());
      expect(session.valueOf('rating'), 4);
      expect(session.valueOf('feedback'), isA<String>());
      expect(session.valueOf('feedback'), 'Very useful');
      expect(
        session.stateView,
        {'rating': 4, 'feedback': 'Very useful'},
      );
      expect(
        () => session.stateView['rating'] = 5,
        throwsUnsupportedError,
      );
    });

    test('notifies listeners when a value changes', () {
      final session = _session();
      var notifications = 0;
      session.addListener(() => notifications++);

      session.setValue('rating', 3);

      expect(notifications, 1);
    });

    test('beginSubmit and endSubmit publish submission state', () {
      final session = _session();
      final states = <bool>[];
      session.addListener(() => states.add(session.isSubmitting));

      session.beginSubmit();
      session.endSubmit();

      expect(states, [true, false]);
      expect(session.isSubmitting, isFalse);
    });
  });

  test('visibleElements evaluates visibleWhen against the full state', () {
    final session = _session();
    final alwaysVisible = Element(type: ElementType.text, style: null);
    final conditionallyVisible = Element(
      type: ElementType.text,
      style: null,
      visibleWhen: Condition.tryParse({
        'attributeName': 'rating',
        'operator': 'more_or_equal',
        'value': 4,
      }),
    );
    final elements = [alwaysVisible, conditionallyVisible];

    expect(session.visibleElements(elements), [alwaysVisible]);

    session.setValue('rating', 4);

    expect(
      session.visibleElements(elements),
      [alwaysVisible, conditionallyVisible],
    );
  });

  group('FormSession completion', () {
    test('finish succeeds exactly once', () {
      final content = _content();
      final campaign = _campaign(content);
      final session = _session(hasFormElements: true);

      expect(
        session.finish(
          FormCloseReason.submitted,
          content: content,
          campaign: campaign,
        ),
        isTrue,
      );
      expect(session.isFinished, isTrue);
      expect(
        session.finish(
          FormCloseReason.dismiss,
          content: content,
          campaign: campaign,
        ),
        isFalse,
      );
    });

    test('consumeStepTransition succeeds once per pending transition', () {
      final session = _session();

      session.beginStepTransition();
      session.beginStepTransition();

      expect(session.consumeStepTransition(), isTrue);
      expect(session.consumeStepTransition(), isTrue);
      expect(session.consumeStepTransition(), isFalse);
    });

    test('finish still succeeds after a step transition is consumed', () {
      final content = _content();
      final campaign = _campaign(content);
      final session = _session();

      session.beginStepTransition();
      expect(session.consumeStepTransition(), isTrue);

      expect(
        session.finish(
          FormCloseReason.explicitClose,
          content: content,
          campaign: campaign,
        ),
        isTrue,
      );
      expect(
        session.finish(
          FormCloseReason.dismiss,
          content: content,
          campaign: campaign,
        ),
        isFalse,
      );
    });
  });

  group('campaignHasFormElements', () {
    test('detects form inputs anywhere in a campaign', () {
      final campaign = _campaign(
        _content(
          elements: [
            {'type': 'text-input', 'attributeName': 'feedback'},
          ],
        ),
      );

      expect(campaignHasFormElements(campaign), isTrue);
    });

    test('detects submit-form buttons anywhere in a campaign', () {
      final campaign = _campaign(
        _content(
          elements: [
            {
              'type': 'button',
              'onClick': {
                'action': 'submit_form',
                'event': {'type': 'survey', 'name': 'submitted'},
                'default': {
                  'do': [
                    {'effect': 'close'},
                  ],
                },
              },
            },
          ],
        ),
      );

      expect(campaignHasFormElements(campaign), isTrue);
    });

    test('returns false for campaigns without inputs or submit buttons', () {
      final campaign = _campaign(
        _content(
          elements: [
            {'type': 'text', 'text': 'Hello'},
            {
              'type': 'button',
              'onClick': {'action': 'close'},
            },
          ],
        ),
      );

      expect(campaignHasFormElements(campaign), isFalse);
    });

    test('ignores submit-form actions on non-button elements', () {
      final campaign = _campaign(
        _content(
          elements: [
            {
              'type': 'text',
              'text': 'Not a submit button',
              'onClick': {
                'action': 'submit_form',
                'event': {'type': 'survey', 'name': 'submitted'},
                'default': {
                  'do': [
                    {'effect': 'close'},
                  ],
                },
              },
            },
          ],
        ),
      );

      expect(campaignHasFormElements(campaign), isFalse);
    });
  });
}
