import 'package:json_annotation/json_annotation.dart';

import '../actions/close.dart';
import 'container.dart';

part 'frame_ui.g.dart';

@JsonSerializable()
class FrameUI {
  final Container container;
  final Close? close;

  const FrameUI({
    required this.container,
    required this.close,
  });

  factory FrameUI.fromJson(Map<String, dynamic> json) => _$FrameUIFromJson(json);
}
