import '../models/internal/condition.dart';

bool evaluateCondition(Condition condition, Map<String, Object?> state) {
  final all = condition.all;
  if (all != null) return all.every((c) => evaluateCondition(c, state));
  final any = condition.any;
  if (any != null) return any.any((c) => evaluateCondition(c, state));

  final actual = state[condition.attributeName];
  final expected = condition.value;
  switch (condition.operator!) {
    case ConditionOperator.isEmpty:
      return _isEmpty(actual);
    case ConditionOperator.isNotEmpty:
      return !_isEmpty(actual);
    case ConditionOperator.equal:
      return _equals(actual, expected);
    case ConditionOperator.notEqual:
      return !_equals(actual, expected);
    case ConditionOperator.less:
      return actual is num && expected is num && actual < expected;
    case ConditionOperator.lessOrEqual:
      return actual is num && expected is num && actual <= expected;
    case ConditionOperator.more:
      return actual is num && expected is num && actual > expected;
    case ConditionOperator.moreOrEqual:
      return actual is num && expected is num && actual >= expected;
  }
}

bool _isEmpty(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  return false;
}

bool _equals(Object? actual, Object? expected) {
  if (actual is num && expected is num) return actual == expected;
  if (actual is String && expected is String) return actual == expected;
  return false;
}
