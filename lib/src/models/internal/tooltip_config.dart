import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../utils/parse_utils.dart';

part 'tooltip_config.g.dart';

@JsonEnum()
enum TooltipPosition {
  @JsonValue('top')
  top,
  @JsonValue('bottom')
  bottom,
  @JsonValue('left')
  left,
  @JsonValue('right')
  right,
  @JsonValue('auto')
  auto,
}

@JsonEnum()
enum ArrowPosition {
  @JsonValue('start')
  start,
  @JsonValue('center')
  center,
  @JsonValue('end')
  end,
}

@JsonSerializable()
class TooltipConfig {
  final TooltipPosition? position;

  final ArrowPosition? arrowPosition;

  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? distanceFromAnchor;

  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? arrowSize;

  final bool? dismissOnTapOutside;

  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? autoDismissSeconds;

  final bool? showBackdrop;

  @JsonKey(fromJson: ParseUtils.parseColor)
  final Color? backdropColor;

  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? maxWidth;

  TooltipConfig({
    this.position,
    this.arrowPosition,
    this.distanceFromAnchor,
    this.arrowSize,
    this.dismissOnTapOutside,
    this.autoDismissSeconds,
    this.showBackdrop,
    this.backdropColor,
    this.maxWidth,
  });

  factory TooltipConfig.fromJson(Map<String, dynamic> json) => _$TooltipConfigFromJson(json);

  TooltipPosition get effectivePosition => position ?? TooltipPosition.auto;
  ArrowPosition get effectiveArrowPosition => arrowPosition ?? ArrowPosition.center;
  double get effectiveDistance => distanceFromAnchor ?? 8.0;
  double get effectiveArrowSize => arrowSize ?? 8.0;
  bool get effectiveDismissOnTapOutside => dismissOnTapOutside ?? true;
  double get effectiveAutoDismissSeconds => autoDismissSeconds ?? 0;
  bool get effectiveShowBackdrop => showBackdrop ?? false;
  Color get effectiveBackdropColor => backdropColor ?? Colors.black.withValues(alpha: 0.3);
  double get effectiveMaxWidth => maxWidth ?? 280.0;
}
