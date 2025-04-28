import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final String name;
  final List<String> urls;

  Event({required this.name, required this.urls});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}
