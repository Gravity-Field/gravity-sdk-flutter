// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'on_click.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnClick _$OnClickFromJson(Map<String, dynamic> json) => OnClick(
      action: $enumDecode(_$ActionEnumMap, json['action']),
      copyData: json['copyData'] as String?,
      step: (json['step'] as num?)?.toInt(),
      url: json['url'] as String?,
      deeplink: json['deeplink'] as String?,
    );

const _$ActionEnumMap = {
  Action.load: 'load',
  Action.impression: 'impression',
  Action.visibleImpression: 'visible_impression',
  Action.close: 'close',
  Action.copy: 'copy',
  Action.cancel: 'cancel',
  Action.followUrl: 'follow_url',
  Action.follow: 'follow',
  Action.followDeeplink: 'follow_deeplink',
  Action.requestPush: 'request_push',
  Action.requestTracking: 'request_tracking',
  Action.unknown: 'unknown',
};
