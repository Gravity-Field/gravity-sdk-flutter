import 'package:json_annotation/json_annotation.dart';

import '../actions/event.dart';
import 'delivery_type.dart';
import 'products.dart';
import 'template_system_name.dart';
import 'variables.dart';

part 'campaign_content.g.dart';

@JsonSerializable()
class CampaignContent {
  final String contentId;
  final String? placeholderId;
  final TemplateSystemName? templateSystemName;
  final DeliveryMethod deliveryMethod;
  final String contentType;
  final Variables variables;
  final Products? products;
  final List<Event>? events;

  CampaignContent({
    required this.contentId,
    this.placeholderId,
    required this.templateSystemName,
    required this.deliveryMethod,
    required this.contentType,
    required this.variables,
    required this.products,
    required this.events,
  });

  factory CampaignContent.fromJson(Map<String, dynamic> json) => _$CampaignContentFromJson(json);
}
