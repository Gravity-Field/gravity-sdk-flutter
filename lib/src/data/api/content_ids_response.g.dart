// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_ids_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CampaignIdsResponse _$CampaignIdsResponseFromJson(Map<String, dynamic> json) =>
    CampaignIdsResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      campaigns:
          (json['campaigns'] as List<dynamic>?)
              ?.map((e) => CampaignId.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

CampaignId _$CampaignIdFromJson(Map<String, dynamic> json) => CampaignId(
  campaignId: json['campaignId'] as String,
  trigger: json['trigger'] as String? ?? '',
);
