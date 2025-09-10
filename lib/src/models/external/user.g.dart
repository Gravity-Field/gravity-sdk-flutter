// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      uid: json['uid'] as String?,
      custom: json['custom'] as String?,
      ses: json['ses'] as String?,
      attributes: (json['attributes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      if (instance.uid case final value?) 'uid': value,
      if (instance.custom case final value?) 'custom': value,
      if (instance.ses case final value?) 'ses': value,
      if (instance.attributes case final value?) 'attributes': value,
    };
