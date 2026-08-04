import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/data/api/content_response.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/follow_url_type.dart';
import 'package:gravity_sdk/src/models/actions/form_action.dart';
import 'package:gravity_sdk/src/models/internal/condition.dart';
import 'package:gravity_sdk/src/models/internal/delivery_type.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';

void main() {
  final json = jsonDecode(
    File('test/fixtures/in_app_survey_payload.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('live in_app_survey_demo payload parses end-to-end', () {
    final response = ContentResponse.fromJson(json);
    final campaign = response.data.single;
    expect(campaign.selector, 'in_app_survey_demo');

    final content = campaign.payload.single.contents.single;
    expect(content.deliveryMethod, DeliveryMethod.bottomSheet);

    final elements = content.variables.elements!;
    expect(elements, hasLength(7));

    final rating = elements[2];
    expect(rating.type, ElementType.optionSelect);
    expect(rating.attributeName, 'rating');
    expect(rating.optionValues, [1, 2, 3, 4, 5]);
    expect(rating.isRequired, isTrue);
    expect(rating.style!.rating!.selectedColor, isNotNull);

    final notNow = elements[3];
    expect(notNow.type, ElementType.button);
    expect(notNow.onClick!.action, Action.close);
    expect(notNow.visibleWhen!.operator, ConditionOperator.isEmpty);

    final feedback = elements[5];
    expect(feedback.type, ElementType.textInput);
    expect(feedback.attributeName, 'feedback');
    expect(feedback.maxLength, 250);
    expect(feedback.minLength, 15);
    expect(feedback.isRequired, isFalse);
    expect(feedback.visibleWhen!.operator, ConditionOperator.lessOrEqual);
    expect(feedback.visibleWhen!.value, 3);

    final submit = elements[6];
    expect(submit.type, ElementType.button);
    final onClick = submit.onClick!;
    expect(onClick.action, Action.submitForm);
    expect(onClick.event!.type, 'in-app-review-v1');
    expect(onClick.event!.name, 'In-app review submitted');
    expect(onClick.routes, hasLength(1));
    final route = onClick.routes!.single;
    expect(route.when!.operator, ConditionOperator.moreOrEqual);
    expect(route.when!.value, 4);
    expect(route.effects.single.effect, FormEffectType.openUrl);
    expect(route.effects.single.urlType, FollowUrlType.browser);
    expect(
      route.effects.single.url,
      startsWith('https://play.google.com/store/apps/details'),
    );
    expect(onClick.defaultRoute!.effects.single.effect, FormEffectType.close);
    expect(submit.visibleWhen!.operator, ConditionOperator.isNotEmpty);
  });
}
