import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TemplateSystemName {
  @JsonValue('snackbar-1')
  snackbar1,
  @JsonValue('snackbar-2')
  snackbar2,
  unknown
}