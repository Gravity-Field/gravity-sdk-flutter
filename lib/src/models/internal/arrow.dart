import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../utils/parse_utils.dart';

part 'arrow.g.dart';

@JsonEnum()
enum ArrowAlignment {
  @JsonValue('start')
  start,
  @JsonValue('center')
  center,
  @JsonValue('end')
  end,
}

@JsonSerializable()
class Arrow {
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? width;

  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? height;

  @JsonKey(fromJson: ParseUtils.parseColor)
  final Color? color;

  final ArrowAlignment? alignment;

  Arrow({
    this.width,
    this.height,
    this.color,
    this.alignment,
  });

  factory Arrow.fromJson(Map<String, dynamic> json) => _$ArrowFromJson(json);

  double get effectiveWidth => width ?? 16.0;
  double get effectiveHeight => height ?? 8.0;
  ArrowAlignment get effectiveAlignment => alignment ?? ArrowAlignment.center;
}
