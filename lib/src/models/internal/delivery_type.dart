import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum DeliveryMethod {
  @JsonValue('snackbar')
  snackBar,
  @JsonValue('modal')
  modal,
  @JsonValue('bottom_sheet')
  bottomSheet,
  @JsonValue('full_screen')
  fullScreen,
  @JsonValue('inline')
  inline,
  @JsonValue('json')
  json,
  @JsonValue('tooltip')
  tooltip,
  @JsonValue('unknown')
  unknown,
}
