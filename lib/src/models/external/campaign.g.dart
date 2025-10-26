// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Campaign _$CampaignFromJson(Map<String, dynamic> json) => Campaign(
  selector: json['selector'] as String?,
  payload: (json['payload'] as List<dynamic>)
      .map((e) => CampaignVariation.fromJson(e as Map<String, dynamic>))
      .toList(),
);
