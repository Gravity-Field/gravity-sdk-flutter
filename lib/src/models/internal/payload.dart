import 'package:json_annotation/json_annotation.dart';
import 'content.dart';

part 'payload.g.dart';

@JsonSerializable()
class Payload {
  final String campaignId;
  final String experienceId;
  final String variationId;
  final String decisionId;
  final List<Content> contents;

  Payload({
    required this.campaignId,
    required this.experienceId,
    required this.variationId,
    required this.decisionId,
    required this.contents,
  });

  factory Payload.fromJson(Map<String, dynamic> json) => _$PayloadFromJson(json);
}