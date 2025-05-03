import 'package:json_annotation/json_annotation.dart';

import 'action_type.dart';

part 'content_action.g.dart';

@JsonSerializable()
class ContentAction {
  final ActionType action;

  const ContentAction({
    required this.action,
  });

  factory ContentAction.fromJson(Map<String, dynamic> json) => _$ContentActionFromJson(json);
}

