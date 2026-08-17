import 'package:json_annotation/json_annotation.dart';

import '../actions/close.dart';
import 'arrow.dart';
import 'drag_handle.dart';
import 'frame_container.dart';
import 'frame_params.dart';

export 'drag_handle.dart';

part 'frame_ui.g.dart';

@JsonSerializable()
class FrameUI {
  final FrameContainer container;
  final Close? close;
  final FrameParams? params;
  final Arrow? arrow;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final DragHandle? dragHandle;

  const FrameUI({
    required this.container,
    this.close,
    this.params,
    this.arrow,
    this.dragHandle,
  });

  factory FrameUI.fromJson(Map<String, dynamic> json) {
    final result = _$FrameUIFromJson(json);
    return FrameUI(
      container: result.container,
      close: result.close,
      params: result.params,
      arrow: result.arrow,
      dragHandle: DragHandle.tryParse(json['dragHandle']),
    );
  }
}
