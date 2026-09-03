import 'package:json_annotation/json_annotation.dart';

import 'action.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  @JsonKey(unknownEnumValue: Action.unknown)
  final Action type;
  final List<String> urls;

  /// `events[].type` as sent by the server. Types without an [Action] member
  /// (e.g. `click`) parse as [Action.unknown] and are told apart only by this.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String rawType;

  Event({required this.type, required this.urls, this.rawType = ''});

  factory Event.fromJson(Map<String, dynamic> json) {
    final result = _$EventFromJson(json);
    final raw = json['type'];
    return Event(
      type: result.type,
      urls: result.urls,
      rawType: raw is String ? raw : '',
    );
  }
}
