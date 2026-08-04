enum ConditionOperator { equal, notEqual, less, lessOrEqual, more, moreOrEqual, isEmpty, isNotEmpty }

const _operatorByWire = <String, ConditionOperator>{
  'equal': ConditionOperator.equal,
  'not_equal': ConditionOperator.notEqual,
  'less': ConditionOperator.less,
  'less_or_equal': ConditionOperator.lessOrEqual,
  'more': ConditionOperator.more,
  'more_or_equal': ConditionOperator.moreOrEqual,
  'is_empty': ConditionOperator.isEmpty,
  'is_not_empty': ConditionOperator.isNotEmpty,
};

const _binaryOperators = {
  ConditionOperator.equal, ConditionOperator.notEqual,
  ConditionOperator.less, ConditionOperator.lessOrEqual,
  ConditionOperator.more, ConditionOperator.moreOrEqual,
};

class Condition {
  final String? attributeName;
  final ConditionOperator? operator;
  final Object? value;
  final List<Condition>? all;
  final List<Condition>? any;

  const Condition._({this.attributeName, this.operator, this.value, this.all, this.any});

  bool get isGroup => all != null || any != null;

  /// Structurally invalid input returns null and never throws — the caller
  /// decides how to demote (hide element / unknown action), see spec §3.7.
  static Condition? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final hasAll = json.containsKey('all');
    final hasAny = json.containsKey('any');
    final hasLeaf = json.containsKey('attributeName') || json.containsKey('operator');
    if ((hasAll || hasAny) && hasLeaf) return null;
    if (hasAll && hasAny) return null;
    if (hasAll || hasAny) {
      final raw = json[hasAll ? 'all' : 'any'];
      if (raw is! List || raw.isEmpty) return null;
      final children = <Condition>[];
      for (final child in raw) {
        final parsed = tryParse(child);
        if (parsed == null) return null;
        children.add(parsed);
      }
      return Condition._(all: hasAll ? children : null, any: hasAny ? children : null);
    }
    final name = json['attributeName'];
    if (name is! String || name.isEmpty) return null;
    final op = _operatorByWire[json['operator']];
    if (op == null) return null;
    final value = json['value'];
    if (_binaryOperators.contains(op)) {
      if (value is! num && value is! String) return null;
      return Condition._(attributeName: name, operator: op, value: value);
    }
    return Condition._(attributeName: name, operator: op);
  }
}
