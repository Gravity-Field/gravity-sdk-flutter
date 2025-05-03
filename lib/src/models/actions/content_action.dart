import 'package:json_annotation/json_annotation.dart';

import 'action.dart';

part 'content_action.g.dart';

@JsonSerializable()
class ContentAction {
  final Action action;

  const ContentAction({
    required this.action,
  });

  factory ContentAction.fromJson(Map<String, dynamic> json) => _$ContentActionFromJson(json);
}

