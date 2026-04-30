import 'package:json_annotation/json_annotation.dart';

part 'rt_rule_argument.g.dart';

@JsonSerializable(createToJson: true)
class RtRuleArgument {
  final String action;
  final List<String> value;

  const RtRuleArgument({
    required this.action,
    required this.value,
  });

  Map<String, dynamic> toJson() => _$RtRuleArgumentToJson(this);

  factory RtRuleArgument.fromJson(Map<String, dynamic> json) => _$RtRuleArgumentFromJson(json);
}
