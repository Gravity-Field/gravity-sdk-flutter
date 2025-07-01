import 'package:json_annotation/json_annotation.dart';

import '../../models/external/user.dart';

part 'content_ids_response.g.dart';

@JsonSerializable()
class CampaignIdsResponse {
  final User user;
  final List<CampaignId> campaigns;

  CampaignIdsResponse({
    required this.user,
    this.campaigns = const [],
  });

  factory CampaignIdsResponse.fromJson(Map<String, dynamic> json) => _$CampaignIdsResponseFromJson(json);
}

@JsonSerializable()
class CampaignId {
  final String campaignId;
  final String trigger;

  CampaignId({
    required this.campaignId,
    this.trigger = '',
  });

  factory CampaignId.fromJson(Map<String, dynamic> json) => _$CampaignIdFromJson(json);
}
