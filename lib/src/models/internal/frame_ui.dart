import 'package:json_annotation/json_annotation.dart';

import '../actions/close.dart';
import 'arrow.dart';
import 'frame_container.dart';
import 'frame_params.dart';

part 'frame_ui.g.dart';

@JsonSerializable()
class FrameUI {
  final FrameContainer container;
  final Close? close;
  final FrameParams? params;
  final Arrow? arrow;

  const FrameUI({required this.container, this.close, this.params, this.arrow});

  factory FrameUI.fromJson(Map<String, dynamic> json) => _$FrameUIFromJson(json);
}
