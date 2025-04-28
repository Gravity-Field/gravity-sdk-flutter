import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum DeliveryMethod {
  @JsonValue('snack-bar')
  snackBar,
  @JsonValue('modal')
  modal,
  @JsonValue('bottom-sheet')
  bottomSheet,
  @JsonValue('fullscreen')
  fullScreen,
  @JsonValue('inline')
  inline,
  @JsonValue('unknown')
  unknown;
}