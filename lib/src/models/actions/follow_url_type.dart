import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum FollowUrlType {
  @JsonValue('browser')
  browser,
  @JsonValue('webview')
  webview,
}
