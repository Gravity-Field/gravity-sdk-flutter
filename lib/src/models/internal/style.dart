import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../utils/parse_utils.dart';
import 'product_container_type.dart';

part 'style.g.dart';

@JsonSerializable(createToJson: false)
class Style {
  @JsonKey(fromJson: ParseUtils.parseColor)
  final Color? backgroundColor;
  final String? backgroundImage;
  @JsonKey(fromJson: ParseUtils.parseColor)
  final Color? pressColor;
  @JsonKey(fromJson: ParseUtils.parseColor)
  final Color? outlineColor;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? cornerRadius;
  final GravitySize? size;
  final GravityMargin? margin;
  final GravityPadding? padding;
  @JsonKey(fromJson: ParseUtils.parseFontSize)
  final double? fontSize;
  @JsonKey(fromJson: ParseUtils.parseFontWeight)
  final FontWeight? fontWeight;
  @JsonKey(fromJson: ParseUtils.parseColor)
  final Color? textColor;
  final GravityTextStyle? textStyle;
  @JsonKey(fromJson: ParseUtils.parseBoxFit)
  final BoxFit? fit;
  final GravityContentAlignment? contentAlignment;
  final GravityLayoutWidth? layoutWidth;
  final GravityPositioned? positioned;
  final GridSettings? gridSettings;
  final ProductContainerType? productContainerType;

  Style({
    this.backgroundColor,
    this.backgroundImage,
    this.pressColor,
    this.outlineColor,
    this.cornerRadius,
    this.size,
    this.margin,
    this.padding,
    this.fontSize,
    this.fontWeight,
    this.textColor,
    this.textStyle,
    this.fit,
    this.contentAlignment,
    this.layoutWidth,
    this.positioned,
    this.gridSettings,
    this.productContainerType,
  });

  factory Style.fromJson(Map<String, dynamic> json) => _$StyleFromJson(json);
}

@JsonSerializable()
class GravitySize {
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? width;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? height;

  GravitySize({required this.width, required this.height});

  factory GravitySize.fromJson(Map<String, dynamic> json) => _$GravitySizeFromJson(json);
}

@JsonSerializable()
class GravityMargin {
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double left;
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double right;
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double top;
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double bottom;

  GravityMargin({required this.left, required this.right, required this.top, required this.bottom});

  factory GravityMargin.fromJson(Map<String, dynamic> json) => _$GravityMarginFromJson(json);
}

@JsonSerializable()
class GravityPadding {
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double left;
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double right;
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double top;
  @JsonKey(fromJson: ParseUtils.parseNonNullableDimension)
  final double bottom;

  GravityPadding({required this.left, required this.right, required this.top, required this.bottom});

  factory GravityPadding.fromJson(Map<String, dynamic> json) => _$GravityPaddingFromJson(json);
}

@JsonSerializable()
class GravityPositioned {
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? left;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? right;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? top;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? bottom;

  GravityPositioned({required this.left, required this.right, required this.top, required this.bottom});

  factory GravityPositioned.fromJson(Map<String, dynamic> json) => _$GravityPositionedFromJson(json);
}

@JsonSerializable()
class GravityTextStyle {
  @JsonKey(fromJson: ParseUtils.parseNonNullableFontSize)
  final double fontSize;
  @JsonKey(fromJson: ParseUtils.parseNonNullableFontWeight)
  final FontWeight fontWeight;
  @JsonKey(fromJson: ParseUtils.parseNonNullableColorBlack)
  final Color color;

  GravityTextStyle({required this.fontSize, required this.fontWeight, required this.color});

  factory GravityTextStyle.fromJson(Map<String, dynamic> json) => _$GravityTextStyleFromJson(json);
}

enum GravityContentAlignment {
  start,
  center,
  end;

  CrossAxisAlignment toCrossAxisAlignment() {
    switch (this) {
      case GravityContentAlignment.start:
        return CrossAxisAlignment.start;
      case GravityContentAlignment.center:
        return CrossAxisAlignment.center;
      case GravityContentAlignment.end:
        return CrossAxisAlignment.end;
    }
  }
}

enum GravityLayoutWidth {
  @JsonValue('match_parent')
  matchParent,
  @JsonValue('wrap_content')
  wrapContent;

  static GravityLayoutWidth fromString(String value) {
    switch (value) {
      case 'match_parent':
        return GravityLayoutWidth.matchParent;
      case 'wrap_content':
        return GravityLayoutWidth.wrapContent;
      default:
        return GravityLayoutWidth.matchParent;
    }
  }
}

@JsonSerializable()
class GridSettings {
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? columns;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? horizontalSpacing;
  @JsonKey(fromJson: ParseUtils.parseDimension)
  final double? verticalSpacing;

  GridSettings({this.columns, this.horizontalSpacing, this.verticalSpacing});

  factory GridSettings.fromJson(Map<String, dynamic> json) => _$GridSettingsFromJson(json);

  int get columnsCount => columns?.toInt() ?? 2;
  double get horizontalSpacingValue => horizontalSpacing ?? 8.0;
  double get verticalSpacingValue => verticalSpacing ?? 8.0;
}
