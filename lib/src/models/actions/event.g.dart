// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  type: $enumDecode(
    _$ActionEnumMap,
    json['type'],
    unknownValue: Action.unknown,
  ),
  urls: (json['urls'] as List<dynamic>).map((e) => e as String).toList(),
);

const _$ActionEnumMap = {
  Action.load: 'load',
  Action.impression: 'impression',
  Action.visibleImpression: 'visible_impression',
  Action.close: 'close',
  Action.copy: 'copy',
  Action.cancel: 'cancel',
  Action.followUrl: 'follow_url',
  Action.followDeeplink: 'follow_deeplink',
  Action.requestPush: 'request_push',
  Action.requestTracking: 'request_tracking',
  Action.unknown: 'unknown',
};
