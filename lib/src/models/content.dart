import 'package:gravity_sdk/src/models/delivery_type.dart';
import 'package:gravity_sdk/src/models/products.dart';

import 'event.dart';
import 'variables.dart';

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

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      contentId: json['contentId'],
      templateId: json['templateId'],
      deliveryMethod: DeliveryMethod.fromString(json['deliveryMethod']),
      contentType: json['contentType'],
      variables: Variables.fromJson(json['variables']),
      products: json['products'] != null ? Products.fromJson(json['products']) : null,
      events: (json['events'] as List).map((e) => Event.fromJson(e)).toList(),
    );
  }
}
