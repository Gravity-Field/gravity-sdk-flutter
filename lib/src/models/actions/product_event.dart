import 'package:gravity_sdk/src/models/actions/product_action.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_event.g.dart';

@JsonSerializable()
class ProductEvent {
  final ProductAction name;
  final List<String> urls;

  ProductEvent({required this.name, required this.urls});

  factory ProductEvent.fromJson(Map<String, dynamic> json) => _$ProductEventFromJson(json);
}