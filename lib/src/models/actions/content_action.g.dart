// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContentAction _$ContentActionFromJson(Map<String, dynamic> json) =>
    ContentAction(
      action: $enumDecode(_$ActionTypeEnumMap, json['action']),
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
