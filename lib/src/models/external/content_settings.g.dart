// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContentSettings _$ContentSettingsFromJson(Map<String, dynamic> json) =>
    ContentSettings(
      skusOnly: json['skusOnly'] as bool? ?? false,
      fields: (json['fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ContentSettingsToJson(ContentSettings instance) =>
    <String, dynamic>{'skusOnly': instance.skusOnly, 'fields': instance.fields};
