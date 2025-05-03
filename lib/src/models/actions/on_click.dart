import 'package:json_annotation/json_annotation.dart';

import 'action.dart';

part 'on_click.g.dart';

@JsonSerializable()
class OnClick {
  final Action action;
  final String? copyData;
  final int? step;
  final String? url;
  final String? deeplink;

  OnClick({
    required this.action,
    this.copyData,
    this.step,
    this.url,
    this.deeplink,
  });

  factory OnClick.fromJson(Map<String, dynamic> json) => _$OnClickFromJson(json);
}
