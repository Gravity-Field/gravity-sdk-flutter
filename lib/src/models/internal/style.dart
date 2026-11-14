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
  @JsonKey(fromJson: ParseUtils.parseBoxFit)
  final BoxFit? backgroundFit;
  final GravityContentAlignment? contentAlignment;
  final GravityVerticalAlignment? verticalAlignment;
  final GravityLayoutWidth? layoutWidth;
  final GravityPositioned? positioned;
  final GridSettings? gridSettings;
  final ProductContainerType? productContainerType;
  final RatingStyle? rating;

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
    this.backgroundFit,
    this.contentAlignment,
    this.verticalAlignment,
    this.layoutWidth,
    this.positioned,
    this.gridSettings,
    this.productContainerType,
    this.rating,
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    final legacyColumns = ParseUtils.parseDimension(json['gridColumns']);
    final settings = json['gridSettings'] as Map<String, dynamic>?;
    final columns = ParseUtils.parseDimension(settings?['columns']);
    if (legacyColumns != null &&
        legacyColumns.isFinite &&
        legacyColumns >= 1 &&
        legacyColumns <= 12 &&
        (columns == null || !columns.isFinite || columns < 1 || columns > 12)) {
      return _$StyleFromJson({
        ...json,
        'gridSettings': {...?settings, 'columns': legacyColumns},
      });
    }
    return _$StyleFromJson(json);
  }
}

class RatingStyle {
  final Color? _selectedColor;
  final Color? _unselectedColor;
  final double? _itemSize;
  final double? _itemSpacing;

  RatingStyle({
    Color? selectedColor,
    Color? unselectedColor,
    double? itemSize,
    double? itemSpacing,
  }) : _selectedColor = selectedColor,
       _unselectedColor = unselectedColor,
       _itemSize = itemSize,
       _itemSpacing = itemSpacing;

  factory RatingStyle.fromJson(Map<String, dynamic> json) => RatingStyle(
    selectedColor: ParseUtils.parseColor(json['selectedColor']),
    unselectedColor: ParseUtils.parseColor(json['unselectedColor']),
    itemSize: ParseUtils.parseDimension(json['itemSize']),
    itemSpacing: ParseUtils.parseDimension(json['itemSpacing']),
  );

  Color get selectedColor => _selectedColor ?? const Color(0xFFF5A623);
  Color get unselectedColor => _unselectedColor ?? const Color(0xFFD9D9D9);
  double get itemSize => _itemSize ?? 36.0;
  double get itemSpacing => _itemSpacing ?? 8.0;
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

enum GravityVerticalAlignment {
  start,
  center,
  end;

  MainAxisAlignment toMainAxisAlignment() {
    switch (this) {
      case GravityVerticalAlignment.start:
        return MainAxisAlignment.start;
      case GravityVerticalAlignment.center:
        return MainAxisAlignment.center;
      case GravityVerticalAlignment.end:
        return MainAxisAlignment.end;
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

  int get columnsCount {
    final value = columns;
    if (value == null || !value.isFinite || value < 1 || value > 12) {
      return 2;
    }
    return value.toInt();
  }
  double get horizontalSpacingValue => _spacingOrDefault(horizontalSpacing);
  double get verticalSpacingValue => _spacingOrDefault(verticalSpacing);

  static double _spacingOrDefault(double? value) =>
      value != null && value.isFinite && value >= 0 ? value : 8.0;
}
