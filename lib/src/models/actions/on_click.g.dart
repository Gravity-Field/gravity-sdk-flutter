// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'on_click.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnClick _$OnClickFromJson(Map<String, dynamic> json) => OnClick(
      action: $enumDecode(_$ActionTypeEnumMap, json['action']),
      copyData: json['copyData'] as String?,
      step: (json['step'] as num?)?.toInt(),
      url: json['url'] as String?,
      deeplink: json['deeplink'] as String?,
    );

const _$ActionTypeEnumMap = {
  ActionType.load: 'load',
  ActionType.impression: 'impression',
  ActionType.visibleImpression: 'visible_impression',
  ActionType.close: 'close',
  ActionType.copy: 'copy',
  ActionType.cancel: 'cancel',
  ActionType.followUrl: 'follow_url',
  ActionType.followDeeplink: 'follow_deeplink',
  ActionType.requestPush: 'request_push',
  ActionType.requestTracking: 'request_tracking',
  ActionType.pimp: 'PIMP',
  ActionType.pclick: 'PCLICK',
  ActionType.unknown: 'unknown',
};
