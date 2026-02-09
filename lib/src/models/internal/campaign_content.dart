import 'package:json_annotation/json_annotation.dart';

import '../../data/error_reporting/error_reporter.dart';
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
  @JsonKey(unknownEnumValue: TemplateSystemName.unknown)
  final TemplateSystemName? templateSystemName;
  @JsonKey(unknownEnumValue: DeliveryMethod.unknown)
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

  factory CampaignContent.fromJson(Map<String, dynamic> json) {
    final result = _$CampaignContentFromJson(json);
    if (result.deliveryMethod == DeliveryMethod.unknown) {
      ErrorReporter.instance.report(
        message: 'Unknown deliveryMethod: ${json['deliveryMethod']}',
        level: 'warning',
        section: 'CampaignContent.fromJson',
        tags: {'category': 'parsing'},
      );
    }
    if (result.templateSystemName == TemplateSystemName.unknown) {
      ErrorReporter.instance.report(
        message: 'Unknown templateSystemName: ${json['templateSystemName']}',
        level: 'warning',
        section: 'CampaignContent.fromJson',
        tags: {'category': 'parsing'},
      );
    }
    return result;
  }
}
