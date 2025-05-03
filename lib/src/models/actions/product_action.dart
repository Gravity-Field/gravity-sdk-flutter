import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProductAction {
  @JsonValue('PIMP')
  pimp,
  @JsonValue('PCLICK')
  pclick,
  unknown;
}