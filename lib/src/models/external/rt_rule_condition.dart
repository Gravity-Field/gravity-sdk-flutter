import 'package:json_annotation/json_annotation.dart';

import 'rt_rule_argument.dart';

part 'rt_rule_condition.g.dart';

@JsonSerializable(createToJson: true)
class RtRuleCondition {
  final String field;
  final List<RtRuleArgument> arguments;

  const RtRuleCondition({
    required this.field,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => _$RtRuleConditionToJson(this);

  factory RtRuleCondition.fromJson(Map<String, dynamic> json) => _$RtRuleConditionFromJson(json);
}
