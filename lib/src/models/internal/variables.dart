import 'package:json_annotation/json_annotation.dart';

import '../actions/content_action.dart';
import 'frame_ui.dart';
import 'element.dart';
import 'tooltip_config.dart';
import 'tooltip_positioning.dart';

part 'variables.g.dart';

@JsonSerializable()
class Variables {
  final FrameUI? frameUI;
  final List<Element>? elements;
  final String? title;
  final ContentAction? onLoad;
  final ContentAction? onImpression;
  final ContentAction? onVisibleImpression;
  final ContentAction? onClose;
  final int? index;
  final TooltipConfig? tooltipConfig;
  final TooltipPositioning? positioning;

  Variables({
    this.frameUI,
    this.elements,
    this.title,
    this.onLoad,
    this.onImpression,
    this.onVisibleImpression,
    this.onClose,
    this.index = 0,
    this.tooltipConfig,
    this.positioning,
  });

  factory Variables.fromJson(Map<String, dynamic> json) => _$VariablesFromJson(json);
}
