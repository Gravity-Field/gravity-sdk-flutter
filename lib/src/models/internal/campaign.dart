import 'package:json_annotation/json_annotation.dart';
import 'campaign_content.dart';

part 'campaign.g.dart';

@JsonSerializable()
class Campaign {
  final String campaignId;
  final String experienceId;
  final String variationId;
  final String decisionId;
  final List<CampaignContent> contents;

  Campaign({
    required this.campaignId,
    required this.experienceId,
    required this.variationId,
    required this.decisionId,
    required this.contents,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) => _$CampaignFromJson(json);
}