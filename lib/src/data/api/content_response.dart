import 'package:gravity_sdk/src/models/internal/campaign.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../models/external/user.dart';

part 'content_response.g.dart';

@JsonSerializable()
class ContentResponse {
  final User user;
  final List<DataItem> data;

  ContentResponse({required this.user, required this.data});

  factory ContentResponse.fromJson(Map<String, dynamic> json) => _$ContentResponseFromJson(json);
}

@JsonSerializable()
class DataItem {
  final String selector;
  final List<Campaign> payload;

  DataItem({required this.selector, required this.payload});

  factory DataItem.fromJson(Map<String, dynamic> json) => _$DataItemFromJson(json);
}
