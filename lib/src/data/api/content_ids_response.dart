import 'package:json_annotation/json_annotation.dart';

import '../../models/external/user.dart';
import '../../utils/parse_utils.dart';

part 'content_ids_response.g.dart';

@JsonSerializable()
class CampaignIdsResponse {
  final User user;
  final List<CampaignId> campaigns;

  const CampaignIdsResponse({
    required this.user,
    this.campaigns = const [],
  });

  factory CampaignIdsResponse.fromJson(Map<String, dynamic> json) =>
      _$CampaignIdsResponseFromJson(json);
}

@JsonSerializable()
class CampaignId {
  final String campaignId;
  final String trigger;
  @JsonKey(fromJson: ParseUtils.parseNonNullableInt)
  final int priority;
  @JsonKey(fromJson: ParseUtils.parseNonNullableInt)
  final int delayTime;

  const CampaignId({
    required this.campaignId,
    this.trigger = '',
    this.priority = 0,
    this.delayTime = 0,
  });

  factory CampaignId.fromJson(Map<String, dynamic> json) =>
      _$CampaignIdFromJson(json);
}
