import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:json_annotation/json_annotation.dart';

part 'container.g.dart';

@JsonSerializable()
class Container {
  final Style style;

  Container({required this.style});


  factory Container.fromJson(Map<String, dynamic> json) => _$ContainerFromJson(json);
}