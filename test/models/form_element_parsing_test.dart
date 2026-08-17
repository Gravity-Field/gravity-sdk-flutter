import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';

Map<String, dynamic> validRating() => {
  'type': 'option-select', 'attributeName': 'rating', 'displayFormat': 'rating',
  'selectMode': 'single', 'required': true,
  'options': [for (var i = 1; i <= 5; i++) {'value': i}],
  'style': {'rating': {'selectedColor': '#f5a623ff', 'unselectedColor': '#d9d9d9ff'}},
};

void main() {
  test('valid option-select parses', () {
    final e = Element.fromJson(validRating());
    expect(e.type, ElementType.optionSelect);
    expect(e.attributeName, 'rating');
    expect(e.options!.map((o) => o.value).toList(), [1, 2, 3, 4, 5]);
    expect(e.options!.map((o) => o.onClick), everyElement(isNull));
    expect(e.isRequired, isTrue);
    expect(e.style!.rating!.itemSize, 36);
  });
  test('valid text-input parses', () {
    final e = Element.fromJson({'type': 'text-input', 'attributeName': 'feedback', 'maxLength': 250, 'minLength': 10, 'placeholder': 'Ваш комментарий'});
    expect(e.type, ElementType.textInput);
    expect(e.maxLength, 250);
    expect(e.minLength, 10);
    expect(e.isFormInput, isTrue);
  });
  group('option onClick', () {
    Map<String, dynamic> withOptionClick(Object? onClick) {
      final json = validRating();
      json['options'] = <Object?>[
        for (var i = 1; i <= 4; i++) {'value': i},
        {'value': 5, 'onClick': onClick},
      ];
      return json;
    }

    test('submit_form onClick on an option parses', () {
      final e = Element.fromJson(
        withOptionClick({
          'action': 'submit_form',
          'closeOnClick': false,
          'event': {
            'type': 'in-app-review-v1',
            'name': 'In-app review submitted',
          },
          'default': {
            'do': [
              {'effect': 'open_step', 'step': 2},
            ],
          },
        }),
      );

      expect(e.type, ElementType.optionSelect);
      expect(e.options!.take(4).map((o) => o.onClick), everyElement(isNull));
      final onClick = e.options!.last.onClick!;
      expect(onClick.action, Action.submitForm);
      expect(onClick.closeOnClick, isFalse);
      expect(onClick.event!.type, 'in-app-review-v1');
      expect(onClick.event!.name, 'In-app review submitted');
      expect(onClick.defaultRoute, isNotNull);
    });

    group('invalid onClick keeps the rating selectable without an action', () {
      final cases = <String, Object?>{
        'unsupported action': {'action': 'close'},
        'unknown action': {'action': 'do_magic'},
        'submit_form without event and default': {
          'action': 'submit_form',
          'closeOnClick': false,
        },
        'not a map': 'tap',
        'missing action': {'closeOnClick': false},
        'explicit null': null,
      };
      cases.forEach((name, onClick) {
        test(name, () {
          final e = Element.fromJson(withOptionClick(onClick));
          expect(e.type, ElementType.optionSelect);
          expect(e.options!.map((o) => o.value).toList(), [1, 2, 3, 4, 5]);
          expect(e.options!.last.onClick, isNull);
        });
      });
    });
  });

  test('text-input showCounter false parses', () {
    final e = Element.fromJson({'type': 'text-input', 'attributeName': 'feedback', 'maxLength': 250, 'showCounter': false});
    expect(e.type, ElementType.textInput);
    expect(e.showCounter, isFalse);
  });
  test('text-input without showCounter keeps it null', () {
    final e = Element.fromJson({'type': 'text-input', 'attributeName': 'feedback'});
    expect(e.type, ElementType.textInput);
    expect(e.showCounter, isNull);
  });
  test('minLength zero is treated as no minimum', () {
    final e = Element.fromJson({'type': 'text-input', 'attributeName': 'feedback', 'minLength': 0});
    expect(e.type, ElementType.textInput);
    expect(e.minLength, isNull);
  });
  test('visibleWhen on plain button parses', () {
    final e = Element.fromJson({'type': 'button', 'text': 'Не сейчас',
      'onClick': {'action': 'close'},
      'visibleWhen': {'attributeName': 'rating', 'operator': 'is_empty'}});
    expect(e.type, ElementType.button);
    expect(e.visibleWhen, isNotNull);
  });
  group('demotion to unknown, no throw', () {
    final cases = <String, Map<String, dynamic>>{
      'string option values': {...validRating(), 'options': [for (var i = 1; i <= 5; i++) {'value': '$i'}]},
      'fractional option value': {...validRating(), 'options': [{'value': 1.5}, {'value': 2}, {'value': 3}, {'value': 4}, {'value': 5}]},
      'wrong order': {...validRating(), 'options': [for (var i = 5; i >= 1; i--) {'value': i}]},
      'four options': {...validRating(), 'options': [for (var i = 1; i <= 4; i++) {'value': i}]},
      'chips displayFormat': {...validRating(), 'displayFormat': 'chips'},
      'multi selectMode': {...validRating(), 'selectMode': 'multi'},
      'missing attributeName': {...validRating()}..remove('attributeName'),
      'options is not a list': {...validRating(), 'options': 'oops'},
      'broken visibleWhen': {'type': 'text', 'text': 'x', 'visibleWhen': {'attributeName': 'r', 'operator': 'contains', 'value': 'x'}},
      'text-input bad maxLength': {'type': 'text-input', 'attributeName': 'f', 'maxLength': 'many'},
      'text-input bad minLength': {'type': 'text-input', 'attributeName': 'f', 'minLength': 'few'},
      'text-input negative minLength': {'type': 'text-input', 'attributeName': 'f', 'minLength': -1},
      'minLength above maxLength': {'type': 'text-input', 'attributeName': 'f', 'minLength': 20, 'maxLength': 5},
      'text-input bad showCounter': {'type': 'text-input', 'attributeName': 'f', 'showCounter': 'nope'},
    };
    cases.forEach((name, json) {
      test(name, () => expect(Element.fromJson(json).type, ElementType.unknown));
    });
  });
  test('legacy element without new fields is unaffected', () {
    final e = Element.fromJson({'type': 'text', 'text': 'hello', 'style': null});
    expect(e.type, ElementType.text);
    expect(e.visibleWhen, isNull);
    expect(e.isFormInput, isFalse);
  });
  group('explicit null form fields demote', () {
    final cases = <String, Map<String, dynamic>>{
      'required': {'type': 'text-input', 'attributeName': 'f', 'required': null},
      'selectMode': {...validRating(), 'selectMode': null},
      'displayFormat': {'type': 'text', 'text': 'x', 'displayFormat': null},
      'placeholder': {'type': 'text-input', 'attributeName': 'f', 'placeholder': null},
      'maxLength': {'type': 'text-input', 'attributeName': 'f', 'maxLength': null},
      'minLength': {'type': 'text-input', 'attributeName': 'f', 'minLength': null},
      'showCounter': {'type': 'text-input', 'attributeName': 'f', 'showCounter': null},
    };
    cases.forEach((name, json) {
      test(name, () => expect(Element.fromJson(json).type, ElementType.unknown));
    });
  });
}
