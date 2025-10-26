// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContentResponse _$ContentResponseFromJson(Map<String, dynamic> json) =>
    ContentResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => Campaign.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
