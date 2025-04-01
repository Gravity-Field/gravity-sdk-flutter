import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/parse_utils.dart';

class Style {
  final Color? backgroundColor;
  final Color? pressColor;
  final Color? outlineColor;
  final double? cornerRadius;
  final GravitySize? size;
  final GravityMargin? margin;
  final GravityPadding? padding;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? textColor;
  final GravityTextStyle? textStyle;
  final BoxFit? fit;
  final GravityContentAlignment? contentAlignment;
  final GravityLayoutWidth? layoutWidth;
  final GravityPositioned? positioned;


  Style({
    this.backgroundColor,
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
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      backgroundColor: ParseUtils.parseColor(json['backgroundColor']),
      pressColor: ParseUtils.parseColor(json['pressColor']),
      outlineColor: ParseUtils.parseColor(json['outlineColor']),
      cornerRadius: ParseUtils.parseDimension(json['cornerRadius']),
      size: json['size'] != null ? GravitySize.fromJson(json['size']) : null,
      margin: json['margin'] != null ? GravityMargin.fromJson(json['margin']) : null,
      padding: json['padding'] != null ? GravityPadding.fromJson(json['padding']) : null,
      fontSize: ParseUtils.parseFontSize(json['fontSize']),
      fontWeight: ParseUtils.parseFontWeight(json['fontWeight']),
      textColor: ParseUtils.parseColor(json['textColor']),
      fit: ParseUtils.parseBoxFit(json['fit']),
      contentAlignment:
          json['contentAlignment'] != null ? GravityContentAlignment.fromString(json['contentAlignment']) : null,
      layoutWidth: json['layoutWidth'] != null ? GravityLayoutWidth.fromString(json['layoutWidth']) : null,
      positioned: json['positioned'] != null ? GravityPositioned.fromJson(json['positioned']) : null,
    );
  }
}

class GravitySize {
  final double? width;
  final double? height;

  GravitySize({required this.width, required this.height});

  factory GravitySize.fromJson(Map<String, dynamic> json) {
    return GravitySize(
      width: ParseUtils.parseDimension(json['width']),
      height: ParseUtils.parseDimension(json['height']),
    );
  }
}

class GravityMargin {
  final double left;
  final double right;
  final double top;
  final double bottom;

  GravityMargin({required this.left, required this.right, required this.top, required this.bottom});

  factory GravityMargin.fromJson(Map<String, dynamic> json) {
    return GravityMargin(
      left: ParseUtils.parseDimension(json['left']) ?? 0,
      right: ParseUtils.parseDimension(json['right']) ?? 0,
      top: ParseUtils.parseDimension(json['top']) ?? 0,
      bottom: ParseUtils.parseDimension(json['bottom']) ?? 0,
    );
  }
}

class GravityPadding {
  final double left;
  final double right;
  final double top;
  final double bottom;

  GravityPadding({required this.left, required this.right, required this.top, required this.bottom});

  factory GravityPadding.fromJson(Map<String, dynamic> json) {
    return GravityPadding(
      left: ParseUtils.parseDimension(json['left']) ?? 0,
      right: ParseUtils.parseDimension(json['right']) ?? 0,
      top: ParseUtils.parseDimension(json['top']) ?? 0,
      bottom: ParseUtils.parseDimension(json['bottom']) ?? 0,
    );
  }
}

class GravityPositioned {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  GravityPositioned({required this.left, required this.right, required this.top, required this.bottom});

  factory GravityPositioned.fromJson(Map<String, dynamic> json) {
    return GravityPositioned(
      left: ParseUtils.parseDimension(json['left']),
      right: ParseUtils.parseDimension(json['right']),
      top: ParseUtils.parseDimension(json['top']),
      bottom: ParseUtils.parseDimension(json['bottom']),
    );
  }
}

class GravityTextStyle {
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  GravityTextStyle({required this.fontSize, required this.fontWeight, required this.color});

  factory GravityTextStyle.fromJson(Map<String, dynamic> json) {
    return GravityTextStyle(
      fontSize: ParseUtils.parseFontSize(json['fontSize']) ?? 0,
      fontWeight: ParseUtils.parseFontWeight(json['fontWeight']) ?? FontWeight.normal,
      color: ParseUtils.parseColor(json['color']) ?? Color(0xFF000000),
    );
  }
}

enum GravityContentAlignment {
  start,
  center,
  end;

  static GravityContentAlignment fromString(String value) {
    switch (value) {
      case 'start':
        return GravityContentAlignment.start;
      case 'center':
        return GravityContentAlignment.center;
      case 'end':
        return GravityContentAlignment.end;
      default:
        return GravityContentAlignment.start;
    }
  }

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
  matchParent,
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
