import 'package:json_annotation/json_annotation.dart';

import '../actions/content_action.dart';
import 'frame_ui.dart';
import 'element.dart';

part 'variables.g.dart';

@JsonSerializable()
class Variables {
  final FrameUI? frameUI;
  final List<Element> elements;
  final ContentAction? onLoad;
  final ContentAction? onImpression;
  final ContentAction? onVisibleImpression;
  final ContentAction? onClose;
  final int? index;

  Variables({
    required this.frameUI,
    required this.elements,
    this.onLoad,
    this.onImpression,
    this.onVisibleImpression,
    this.onClose,
    this.index = 0,
  });

  factory Variables.fromJson(Map<String, dynamic> json) => _$VariablesFromJson(json);
}
