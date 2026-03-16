import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/internal/style.dart';
import 'package:json_annotation/json_annotation.dart';

part 'frame_container.g.dart';

@JsonSerializable()
class FrameContainer {
  final Style? style;
  final OnClick? onClick;

  FrameContainer({this.style, this.onClick});

  factory FrameContainer.fromJson(Map<String, dynamic> json) => _$FrameContainerFromJson(json);
}
