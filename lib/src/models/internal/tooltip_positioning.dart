import 'package:json_annotation/json_annotation.dart';
import '../../utils/parse_utils.dart';

part 'tooltip_positioning.g.dart';

@JsonEnum()
enum TooltipDirection {
  @JsonValue('top')
  top,
  @JsonValue('bottom')
  bottom,
  @JsonValue('left')
  left,
  @JsonValue('right')
  right,
}

@JsonEnum()
enum TooltipAlignment {
  @JsonValue('start')
  start,
  @JsonValue('center')
  center,
  @JsonValue('end')
  end,
}

@JsonSerializable()
class TooltipPositioning {
  final TooltipDirection? direction;
  final TooltipAlignment? alignment;

  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? offset;

  final bool? allowFlip;

  TooltipPositioning({
    this.direction,
    this.alignment,
    this.offset,
    this.allowFlip,
  });

  factory TooltipPositioning.fromJson(Map<String, dynamic> json) =>
      _$TooltipPositioningFromJson(json);

  TooltipDirection get effectiveDirection => direction ?? TooltipDirection.bottom;
  TooltipAlignment get effectiveAlignment => alignment ?? TooltipAlignment.center;
  double get effectiveOffset => offset ?? 8.0;
  bool get effectiveAllowFlip => allowFlip ?? true;
}
