import 'package:json_annotation/json_annotation.dart';

import 'delivery_type.dart';
import '../actions/event.dart';
import 'products.dart';
import 'variables.dart';

part 'content.g.dart';

@JsonSerializable()
class Content {
  final String contentId;
  final String templateId;
  final DeliveryMethod deliveryMethod;
  final String contentType;
  final Variables variables;
  final Products? products;
  final List<Event> events;

  Content({
    required this.contentId,
    required this.templateId,
    required this.deliveryMethod,
    required this.contentType,
    required this.variables,
    required this.products,
    required this.events,
  });

  factory Content.fromJson(Map<String, dynamic> json) => _$ContentFromJson(json);
}
