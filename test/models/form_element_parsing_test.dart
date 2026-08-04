import 'package:flutter_test/flutter_test.dart';
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
    expect(e.optionValues, [1, 2, 3, 4, 5]);
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
    };
    cases.forEach((name, json) {
      test(name, () => expect(Element.fromJson(json).type, ElementType.unknown));
    });
  });
}
