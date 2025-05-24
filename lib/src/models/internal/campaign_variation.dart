import 'package:json_annotation/json_annotation.dart';
import 'campaign_content.dart';

part 'campaign_variation.g.dart';

@JsonSerializable()
class CampaignVariation {
  final String campaignId;
  final String experienceId;
  final String variationId;
  final String decisionId;
  final List<CampaignContent> contents;

  CampaignVariation({
    required this.campaignId,
    required this.experienceId,
    required this.variationId,
    required this.decisionId,
    required this.contents,
  });

  factory CampaignVariation.fromJson(Map<String, dynamic> json) => _$CampaignVariationFromJson(json);
}