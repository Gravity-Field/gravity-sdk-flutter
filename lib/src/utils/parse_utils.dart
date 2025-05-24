import 'package:flutter/material.dart';

class ParseUtils {

  static Color parseNonNullableColorBlack(Object? color) {
    return parseColor(color) ?? Colors.black;
  }

  static Color? parseColor(Object? color) {
    if (color == null) {
      return null;
    }

    if (color is String && color.startsWith('#')) {
      final hexColor = int.tryParse(color.substring(1), radix: 16);
      return hexColor != null ? Color(hexColor) : null;
    }

    return null;
  }

  static double parseNonNullableDimension(Object? dimension) {
    return parseDimension(dimension) ?? 0.0;
  }

  static double? parseDimension(Object? dimension) {
    if (dimension == null) {
      return null;
    }

    if (dimension is double) {
      return dimension;
    }

    if (dimension is int) {
      return dimension.toDouble();
    }

    if (dimension is String) {
      if (dimension.contains('px')) {
        return double.tryParse(dimension.replaceAll('px', ''));
      }
    }

    return null;
  }

  static double parseNonNullableFontSize(Object? fontSize) {
    return parseFontSize(fontSize) ?? 0.0;
  }

  static double? parseFontSize(Object? fontSize) {
    if (fontSize == null) {
      return null;
    }

    if (fontSize is int) {
      return fontSize.toDouble();
    }

    if (fontSize is double) {
      return fontSize;
    }

    return null;
  }

  static FontWeight parseNonNullableFontWeight(Object? fontWeight) {
    return parseFontWeight(fontWeight) ?? FontWeight.normal;
  }

  static FontWeight? parseFontWeight(Object? fontWeight) {
    if (fontWeight == null) {
      return null;
    }

    if (fontWeight is String) {
      switch (fontWeight) {
        case '100':
          return FontWeight.w100;
        case '200':
          return FontWeight.w200;
        case '300':
          return FontWeight.w300;
        case '400':
          return FontWeight.w400;
        case '500':
          return FontWeight.w500;
        case '600':
          return FontWeight.w600;
        case '700':
          return FontWeight.w700;
        case '800':
          return FontWeight.w800;
        case '900':
          return FontWeight.w900;
      }
    }

    return null;
  }

  static BoxFit? parseBoxFit(Object? fit) {
    if (fit == null) {
      return null;
    }

    if (fit is String) {
      switch (fit) {
        case 'fill':
          return BoxFit.fill;
        case 'contain':
          return BoxFit.contain;
        case 'cover':
          return BoxFit.cover;
        case 'fitWidth':
          return BoxFit.fitWidth;
        case 'fitHeight':
          return BoxFit.fitHeight;
        case 'none':
          return BoxFit.none;
        case 'scaleDown':
          return BoxFit.scaleDown;
      }
    }

    return null;
  }
}
