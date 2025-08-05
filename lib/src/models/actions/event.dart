import 'package:json_annotation/json_annotation.dart';

import 'action.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  @JsonKey(unknownEnumValue: Action.unknown)
  final Action type;
  final List<String> urls;

  Event({required this.type, required this.urls});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}
