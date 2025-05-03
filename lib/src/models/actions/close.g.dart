// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'close.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Close _$CloseFromJson(Map<String, dynamic> json) => Close(
      image: json['image'] as String?,
      onClick: json['onClick'] == null
          ? null
          : OnClick.fromJson(json['onClick'] as Map<String, dynamic>),
      style: Style.fromJson(json['style'] as Map<String, dynamic>),
    );
