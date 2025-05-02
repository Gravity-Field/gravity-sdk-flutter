// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Options _$OptionsFromJson(Map<String, dynamic> json) => Options(
      isReturnCounter: json['isReturnCounter'] as bool? ?? false,
      isReturnUserInfo: json['isReturnUserInfo'] as bool? ?? false,
      isReturnAnalyticsMetadata:
          json['isReturnAnalyticsMetadata'] as bool? ?? false,
      isImplicitPageview: json['isImplicitPageview'] as bool? ?? false,
      isImplicitImpression: json['isImplicitImpression'] as bool? ?? true,
    );

Map<String, dynamic> _$OptionsToJson(Options instance) => <String, dynamic>{
      'isReturnCounter': instance.isReturnCounter,
      'isReturnUserInfo': instance.isReturnUserInfo,
      'isReturnAnalyticsMetadata': instance.isReturnAnalyticsMetadata,
      'isImplicitPageview': instance.isImplicitPageview,
      'isImplicitImpression': instance.isImplicitImpression,
    };
