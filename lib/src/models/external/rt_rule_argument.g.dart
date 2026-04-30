// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rt_rule_argument.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RtRuleArgument _$RtRuleArgumentFromJson(Map<String, dynamic> json) =>
    RtRuleArgument(
      action: json['action'] as String,
      value: (json['value'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$RtRuleArgumentToJson(RtRuleArgument instance) =>
    <String, dynamic>{'action': instance.action, 'value': instance.value};
