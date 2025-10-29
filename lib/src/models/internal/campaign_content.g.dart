// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CampaignContent _$CampaignContentFromJson(Map<String, dynamic> json) =>
    CampaignContent(
      contentId: json['contentId'] as String,
      placeholderId: json['placeholderId'] as String?,
      templateSystemName: $enumDecodeNullable(
        _$TemplateSystemNameEnumMap,
        json['templateSystemName'],
      ),
      deliveryMethod: $enumDecode(
        _$DeliveryMethodEnumMap,
        json['deliveryMethod'],
      ),
      contentType: json['contentType'] as String,
      variables: Variables.fromJson(json['variables'] as Map<String, dynamic>),
      products: json['products'] == null
          ? null
          : Products.fromJson(json['products'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>?)
          ?.map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

const _$TemplateSystemNameEnumMap = {
  TemplateSystemName.snackbar1: 'snackbar-1',
  TemplateSystemName.snackbar2: 'snackbar-2',
  TemplateSystemName.unknown: 'unknown',
};

const _$DeliveryMethodEnumMap = {
  DeliveryMethod.snackBar: 'snackbar',
  DeliveryMethod.modal: 'modal',
  DeliveryMethod.bottomSheet: 'bottom_sheet',
  DeliveryMethod.fullScreen: 'full_screen',
  DeliveryMethod.inline: 'inline',
  DeliveryMethod.unknown: 'unknown',
};
