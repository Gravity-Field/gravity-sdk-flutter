// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContentAction _$ContentActionFromJson(Map<String, dynamic> json) =>
    ContentAction(
      action: $enumDecode(_$ActionEnumMap, json['action']),
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
