// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rt_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RtRule _$RtRuleFromJson(Map<String, dynamic> json) => RtRule(
  id: (json['id'] as num?)?.toInt(),
  type: json['type'] as String,
  slots: (json['slots'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  conditions: (json['conditions'] as List<dynamic>)
      .map((e) => RtRuleCondition.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RtRuleToJson(RtRule instance) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'slots': instance.slots,
  'conditions': instance.conditions,
};
