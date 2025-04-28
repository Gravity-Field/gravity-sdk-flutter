// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Content _$ContentFromJson(Map<String, dynamic> json) => Content(
      contentId: json['contentId'] as String,
      templateId: json['templateId'] as String,
      deliveryMethod:
          $enumDecode(_$DeliveryMethodEnumMap, json['deliveryMethod']),
      contentType: json['contentType'] as String,
      variables: Variables.fromJson(json['variables'] as Map<String, dynamic>),
      products: json['products'] == null
          ? null
          : Products.fromJson(json['products'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>)
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

const _$DeliveryMethodEnumMap = {
  DeliveryMethod.snackBar: 'snack-bar',
  DeliveryMethod.modal: 'modal',
  DeliveryMethod.bottomSheet: 'bottom-sheet',
  DeliveryMethod.fullScreen: 'fullscreen',
  DeliveryMethod.inline: 'inline',
  DeliveryMethod.unknown: 'unknown',
};
