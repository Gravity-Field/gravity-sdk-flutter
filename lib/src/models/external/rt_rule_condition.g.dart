// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rt_rule_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RtRuleCondition _$RtRuleConditionFromJson(Map<String, dynamic> json) =>
    RtRuleCondition(
      field: json['field'] as String,
      arguments: (json['arguments'] as List<dynamic>)
          .map((e) => RtRuleArgument.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RtRuleConditionToJson(RtRuleCondition instance) =>
    <String, dynamic>{'field': instance.field, 'arguments': instance.arguments};
