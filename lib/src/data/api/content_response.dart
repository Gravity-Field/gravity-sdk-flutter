import 'package:json_annotation/json_annotation.dart';

import '../../models/external/campaign.dart';
import '../../models/external/user.dart';
import '../../models/internal/campaign_variation.dart';

part 'content_response.g.dart';

@JsonSerializable()
class ContentResponse {
  final User user;
  final List<Campaign> data;

  ContentResponse({required this.user, required this.data});

  factory ContentResponse.fromJson(Map<String, dynamic> json) => _$ContentResponseFromJson(json);
}

