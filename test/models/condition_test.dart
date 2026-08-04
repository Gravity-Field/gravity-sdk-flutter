import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sdk/src/models/internal/condition.dart';

void main() {
  group('Condition.tryParse leaf', () {
    test('parses payload operators', () {
      final c = Condition.tryParse({'attributeName': 'rating', 'operator': 'less_or_equal', 'value': 3})!;
      expect(c.attributeName, 'rating');
      expect(c.operator, ConditionOperator.lessOrEqual);
      expect(c.value, 3);
    });
    test('parses is_empty without value', () {
      final c = Condition.tryParse({'attributeName': 'rating', 'operator': 'is_empty'})!;
      expect(c.operator, ConditionOperator.isEmpty);
    });
    for (final bad in [
      {'attributeName': '', 'operator': 'equal', 'value': 1},          // пустой attributeName
      {'attributeName': 'r', 'operator': 'contains', 'value': 'x'},    // оператор вне v1
      {'attributeName': 'r', 'operator': 'equal'},                     // бинарный без value
      {'attributeName': 'r', 'operator': 'equal', 'value': true},      // bool value
      {'operator': 'equal', 'value': 1},                               // нет attributeName
      'not a map', 42, null,
    ]) {
      test('invalid leaf -> null: $bad', () => expect(Condition.tryParse(bad), isNull));
    }
  });
  group('Condition.tryParse groups', () {
    test('parses all/any recursively', () {
      final c = Condition.tryParse({'all': [
        {'attributeName': 'a', 'operator': 'is_empty'},
        {'any': [{'attributeName': 'b', 'operator': 'equal', 'value': 'x'}]},
      ]})!;
      expect(c.all, hasLength(2));
      expect(c.all![1].any, hasLength(1));
    });
    for (final bad in [
      {'all': []},                                                     // пустая группа
      {'any': [{'attributeName': 'r', 'operator': 'nope'}]},           // невалидный ребёнок
      {'all': [{'attributeName': 'a', 'operator': 'is_empty'}], 'any': [{'attributeName': 'a', 'operator': 'is_empty'}]}, // обе группы
      {'attributeName': 'a', 'operator': 'is_empty', 'all': [{'attributeName': 'b', 'operator': 'is_empty'}]},            // лист+группа
    ]) {
      test('invalid group -> null: $bad', () => expect(Condition.tryParse(bad), isNull));
    }
  });
}
