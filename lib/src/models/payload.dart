import 'content.dart';

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

  factory Payload.fromJson(Map<String, dynamic> json) {
    return Payload(
      campaignId: json['campaignId'],
      experienceId: json['experienceId'],
      variationId: json['variationId'],
      decisionId: json['decisionId'],
      contents: (json['contents'] as List).map((e) => Content.fromJson(e)).toList(),
    );
  }
}