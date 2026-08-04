import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/forms/input_validity.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';

Element _input({bool required = false, int? minLength}) => Element(
  type: ElementType.textInput,
  style: null,
  attributeName: 'feedback',
  isRequired: required,
  minLength: minLength,
);

void main() {
  group('required', () {
    test('rejects null and whitespace-only values', () {
      expect(isInputValueValid(_input(required: true), null), isFalse);
      expect(isInputValueValid(_input(required: true), '   '), isFalse);
    });
    test('accepts non-empty text and numbers', () {
      expect(isInputValueValid(_input(required: true), 'x'), isTrue);
      expect(isInputValueValid(_input(required: true), 4), isTrue);
    });
  });

  group('minLength', () {
    test('minLength implies the field must be filled', () {
      expect(isInputValueValid(_input(minLength: 3), null), isFalse);
      expect(isInputValueValid(_input(minLength: 3), ''), isFalse);
      expect(isInputValueValid(_input(minLength: 3), '   '), isFalse);
    });
    test('empty optional value without minLength passes', () {
      expect(isInputValueValid(_input(), null), isTrue);
      expect(isInputValueValid(_input(), ''), isTrue);
    });
    test('non-empty text below the minimum fails', () {
      expect(isInputValueValid(_input(minLength: 3), 'ab'), isFalse);
      expect(isInputValueValid(_input(minLength: 3), 'abc'), isTrue);
    });
    test('trimmed length is what counts', () {
      expect(isInputValueValid(_input(minLength: 3), '  ab  '), isFalse);
      expect(isInputValueValid(_input(minLength: 3), ' abc '), isTrue);
    });
    test('counts grapheme clusters like the maxLength counter', () {
      expect(isInputValueValid(_input(minLength: 3), '😀😀'), isFalse);
      expect(isInputValueValid(_input(minLength: 3), '😀😀😀'), isTrue);
    });
    test('required empty value with minLength still fails via required', () {
      expect(
        isInputValueValid(_input(required: true, minLength: 3), ''),
        isFalse,
      );
    });
    test('non-string values are not length-checked', () {
      expect(isInputValueValid(_input(minLength: 3), 4), isTrue);
    });
  });
}
