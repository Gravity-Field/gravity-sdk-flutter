import 'package:json_annotation/json_annotation.dart';

import 'rt_rule_condition.dart';

part 'rt_rule.g.dart';

@JsonSerializable(createToJson: true)
class RtRule {
  final int? id;
  final String type;
  final List<int>? slots;
  final List<RtRuleCondition> conditions;

  const RtRule({
    this.id,
    required this.type,
    this.slots,
    required this.conditions,
  });

  Map<String, dynamic> toJson() => _$RtRuleToJson(this);

  factory RtRule.fromJson(Map<String, dynamic> json) => _$RtRuleFromJson(json);
}
