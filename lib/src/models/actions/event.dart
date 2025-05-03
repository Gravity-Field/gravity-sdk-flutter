import 'package:gravity_sdk/src/models/actions/action_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final ActionType name;
  final List<String> urls;

  Event({required this.name, required this.urls});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}
