// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      name: $enumDecode(_$ActionTypeEnumMap, json['name']),
      urls: (json['urls'] as List<dynamic>).map((e) => e as String).toList(),
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
