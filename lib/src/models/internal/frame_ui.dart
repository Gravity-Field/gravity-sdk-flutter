import 'package:json_annotation/json_annotation.dart';

import '../actions/close.dart';
import 'frame_container.dart';
import 'frame_params.dart';

part 'frame_ui.g.dart';

@JsonSerializable()
class FrameUI {
  final FrameContainer container;
  final Close? close;
  final FrameParams? params;

  const FrameUI({required this.container, required this.close, this.params});

  factory FrameUI.fromJson(Map<String, dynamic> json) => _$FrameUIFromJson(json);
}
