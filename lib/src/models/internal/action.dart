import 'package:json_annotation/json_annotation.dart';

part 'action.g.dart';

@JsonSerializable()
class Action {
  final String action;

  Action({required this.action});

  factory Action.fromJson(Map<String, dynamic> json) => _$ActionFromJson(json);

}