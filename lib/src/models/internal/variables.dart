import 'package:json_annotation/json_annotation.dart';

import 'frame_ui.dart';
import 'element.dart';
import 'action.dart';

part 'variables.g.dart';

@JsonSerializable()
class Variables {
  final FrameUI? frameUI;
  final List<Element> elements;
  final Action? onLoad;
  final Action? onImpression;
  final Action? onVisibleImpression;
  final Action? onClose;

  Variables({
    required this.frameUI,
    required this.elements,
    this.onLoad,
    this.onImpression,
    this.onVisibleImpression,
    this.onClose,
  });

  factory Variables.fromJson(Map<String, dynamic> json) => _$VariablesFromJson(json);
}
