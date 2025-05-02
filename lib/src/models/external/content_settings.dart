import 'package:json_annotation/json_annotation.dart';

part 'content_settings.g.dart';

@JsonSerializable(createToJson: true)
class ContentSettings {
  final bool skusOnly;
  final List<String>? fields;

  const ContentSettings({
    this.skusOnly = false,
    this.fields,
  });

  Map<String, dynamic> toJson() => _$ContentSettingsToJson(this);

  factory ContentSettings.fromJson(Map<String, dynamic> json) => _$ContentSettingsFromJson(json);
}
