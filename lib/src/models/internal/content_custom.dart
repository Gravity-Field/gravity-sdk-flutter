import 'package:json_annotation/json_annotation.dart';

part 'content_custom.g.dart';

@JsonSerializable()
class ContentCustom {
  final String? json;

  ContentCustom({this.json});

  factory ContentCustom.fromJson(Map<String, dynamic> json) => _$ContentCustomFromJson(json);
}
