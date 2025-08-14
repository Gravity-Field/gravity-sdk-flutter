import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProductAction {
  @JsonValue('impression')
  impression,
  @JsonValue('visible_impression')
  visibleImpression,
  @JsonValue('click')
  click,
  unknown;
}
