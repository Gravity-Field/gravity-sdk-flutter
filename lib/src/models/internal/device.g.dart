// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'ua': instance.userAgent,
      if (instance.id case final value?) 'id': value,
      if (instance.tracking case final value?) 'tracking': value,
      if (instance.permission case final value?) 'permission': value,
    };
