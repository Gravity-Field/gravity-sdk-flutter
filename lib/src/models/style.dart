import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/parse_utils.dart';

class Style {
  final Color? color;
  final Color? pressColor;
  final Color? outlineColor;
  final double? cornerRadius;
  final GravitySize? size;
  final GravityMargin? margin;
  final GravityPadding? padding;
  final double? fontSize;
  final FontWeight? fontWeight;
  final GravityTextStyle? textStyle;
  final BoxFit? fit;
  final GravityContentAlignment? contentAlignment;
  final GravityLayoutWidth? layoutWidth;

  Style({
    this.color,
    this.pressColor,
    this.outlineColor,
    this.cornerRadius,
    this.size,
    this.margin,
    this.padding,
    this.fontSize,
    this.fontWeight,
    this.textStyle,
    this.fit,
    this.contentAlignment,
    this.layoutWidth,
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      color: ParseUtils.parseColor(json['color']),
      pressColor: ParseUtils.parseColor(json['pressColor']),
      outlineColor: ParseUtils.parseColor(json['outlineColor']),
      cornerRadius: ParseUtils.parseDimension(json['cornerRadius']),
      size: json['size'] != null ? GravitySize.fromJson(json['size']) : null,
      margin: json['margin'] != null ? GravityMargin.fromJson(json['margin']) : null,
      padding: json['padding'] != null ? GravityPadding.fromJson(json['padding']) : null,
      fontSize: ParseUtils.parseFontSize(json['fontSize']),
      fontWeight: ParseUtils.parseFontWeight(json['fontWeight']),
      textStyle: json['textStyle'] != null ? GravityTextStyle.fromJson(json['textStyle']) : null,
      fit: ParseUtils.parseBoxFit(json['fit']),
      contentAlignment: json['contentAlignment'] != null ? GravityContentAlignment.fromString(json['contentAlignment']) : null,
      layoutWidth: json['layoutWidth'] != null ? GravityLayoutWidth.fromString(json['layoutWidth']) : null,
    );
  }
}

class GravitySize {
  final double width;
  final double height;

  GravitySize({required this.width, required this.height});

  factory GravitySize.fromJson(Map<String, dynamic> json) {
    return GravitySize(
      width: ParseUtils.parseDimension(json['width']) ?? 0,
      height: ParseUtils.parseDimension(json['height']) ?? 0,
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
