// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign_variation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CampaignVariation _$CampaignVariationFromJson(Map<String, dynamic> json) =>
    CampaignVariation(
      campaignId: json['campaignId'] as String,
      experienceId: json['experienceId'] as String,
      variationId: json['variationId'] as String,
      decisionId: json['decisionId'] as String,
      contents: (json['contents'] as List<dynamic>)
          .map((e) => CampaignContent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
