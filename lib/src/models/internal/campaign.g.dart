// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Campaign _$CampaignFromJson(Map<String, dynamic> json) => Campaign(
      campaignId: json['campaignId'] as String,
      experienceId: json['experienceId'] as String,
      variationId: json['variationId'] as String,
      decisionId: json['decisionId'] as String,
      contents: (json['contents'] as List<dynamic>)
          .map((e) => CampaignContent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
