import 'package:json_annotation/json_annotation.dart';

import '../internal/campaign_variation.dart';

part 'campaign.g.dart';

@JsonSerializable()
class Campaign {
  final String selector;
  final List<CampaignVariation> payload;

  Campaign({required this.selector, required this.payload});

  factory Campaign.fromJson(Map<String, dynamic> json) => _$CampaignFromJson(json);
}
