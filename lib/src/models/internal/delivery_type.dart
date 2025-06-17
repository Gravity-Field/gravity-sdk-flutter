import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum DeliveryMethod {
  @JsonValue('snackbar')
  snackBar,
  @JsonValue('modal')
  modal,
  @JsonValue('bottom_sheet')
  bottomSheet,
  @JsonValue('fullscreen')
  fullScreen,
  @JsonValue('inline')
  inline,
  @JsonValue('unknown')
  unknown;
}