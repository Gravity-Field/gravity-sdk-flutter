import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ActionType {
  @JsonValue('load')
  load,
  @JsonValue('impression')
  impression,
  @JsonValue('visible_impression')
  visibleImpression,
  @JsonValue('close')
  close,
  @JsonValue('copy')
  copy,
  @JsonValue('cancel')
  cancel,
  @JsonValue('follow_url')
  followUrl,
  @JsonValue('follow_deeplink')
  followDeeplink,
  @JsonValue('request_push')
  requestPush,
  @JsonValue('request_tracking')
  requestTracking,
  @JsonValue('PIMP')
  pimp,
  @JsonValue('PCLICK')
  pclick,
  @JsonValue('unknown')
  unknown;
}
