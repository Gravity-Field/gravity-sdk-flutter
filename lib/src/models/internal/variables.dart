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

  /// Raw `variables` object exactly as it arrived from the server, including
  /// keys that have no typed counterpart. Shallow-unmodifiable. Empty for a
  /// [Variables] constructed by hand rather than parsed from JSON.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, dynamic> raw;

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
    Map<String, dynamic>? raw,
  }) : raw = raw == null
            ? const <String, dynamic>{}
            : Map<String, dynamic>.unmodifiable(raw);

  /// Reads an arbitrary `variables` key, e.g. `variables['my-selector']`.
  Object? operator [](String key) => raw[key];

  /// Reads an arbitrary `variables` key and returns it only if it is a [T].
  T? valueOf<T>(String key) {
    final value = raw[key];
    return value is T ? value : null;
  }

  factory Variables.fromJson(Map<String, dynamic> json) {
    final result = _$VariablesFromJson(json);
    return Variables(
      frameUI: result.frameUI,
      elements: result.elements,
      title: result.title,
      onLoad: result.onLoad,
      onImpression: result.onImpression,
      onVisibleImpression: result.onVisibleImpression,
      onClose: result.onClose,
      index: result.index,
      tooltipConfig: result.tooltipConfig,
      positioning: result.positioning,
      raw: json,
    );
  }
}
