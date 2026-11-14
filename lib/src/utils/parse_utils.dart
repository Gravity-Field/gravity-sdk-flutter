import 'package:flutter/material.dart';

class ParseUtils {
  static const _numberWhitespace = <int>{
    0x0009,
    0x000A,
    0x000B,
    0x000C,
    0x000D,
    0x0020,
    0x0085,
    0x00A0,
    0x1680,
    0x2000,
    0x2001,
    0x2002,
    0x2003,
    0x2004,
    0x2005,
    0x2006,
    0x2007,
    0x2008,
    0x2009,
    0x200A,
    0x2028,
    0x2029,
    0x202F,
    0x205F,
    0x3000,
  };

  static bool _isDecimalDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  /// Parses numbers or exact ASCII decimal strings, truncating toward zero.
  /// Strings may include a sign, decimal point or exponent. Only Unicode
  /// White_Space is trimmed; BOM, zero-width space and hex are invalid.
  /// Finite values and valid decimal strings saturate to the int64 range.
  /// Invalid inputs and non-finite JSON numbers return zero.
  static int parseNonNullableInt(Object? value) {
    if (value is num) return value.isFinite ? value.toInt() : 0;
    if (value is! String) return 0;
    var start = 0;
    var end = value.length;
    while (start < end && _numberWhitespace.contains(value.codeUnitAt(start))) {
      start++;
    }
    while (end > start &&
        _numberWhitespace.contains(value.codeUnitAt(end - 1))) {
      end--;
    }
    if (start == end) return 0;
    final text = value.substring(start, end);

    // Scan the grammar once: no regex retries or backtracking on malformed input.
    var cursor = 0;
    final negative = text.codeUnitAt(cursor) == 45;
    if (negative || text.codeUnitAt(cursor) == 43) cursor++;
    final mantissaStart = cursor;
    while (cursor < text.length && _isDecimalDigit(text.codeUnitAt(cursor))) {
      cursor++;
    }
    final wholeDigits = cursor - mantissaStart;
    var fractionDigits = 0;
    if (cursor < text.length && text.codeUnitAt(cursor) == 46) {
      cursor++;
      final fractionStart = cursor;
      while (cursor < text.length && _isDecimalDigit(text.codeUnitAt(cursor))) {
        cursor++;
      }
      fractionDigits = cursor - fractionStart;
    }
    if (wholeDigits == 0 && fractionDigits == 0) return 0;
    final mantissaEnd = cursor;

    // Cap exponent accumulation before expanding any powers or integer digits.
    final exponentCap = text.length + 19;
    var exponent = 0;
    if (cursor < text.length &&
        (text.codeUnitAt(cursor) == 101 || text.codeUnitAt(cursor) == 69)) {
      cursor++;
      var negativeExponent = false;
      if (cursor < text.length) {
        negativeExponent = text.codeUnitAt(cursor) == 45;
        if (negativeExponent || text.codeUnitAt(cursor) == 43) cursor++;
      }
      final exponentStart = cursor;
      while (cursor < text.length && _isDecimalDigit(text.codeUnitAt(cursor))) {
        if (exponent < exponentCap) {
          exponent = exponent * 10 + text.codeUnitAt(cursor) - 48;
          if (exponent > exponentCap) exponent = exponentCap;
        }
        cursor++;
      }
      if (cursor == exponentStart) return 0;
      if (negativeExponent) exponent = -exponent;
    }
    if (cursor != text.length) return 0;

    final digits = text
        .substring(mantissaStart, mantissaEnd)
        .replaceAll('.', '');
    var firstNonzero = 0;
    while (firstNonzero < digits.length &&
        digits.codeUnitAt(firstNonzero) == 48) {
      firstNonzero++;
    }
    if (firstNonzero == digits.length) return 0;
    final integerDigits = wholeDigits + exponent - firstNonzero;
    if (integerDigits <= 0) return 0;
    final limit = negative ? '9223372036854775808' : '9223372036854775807';
    if (integerDigits > limit.length) {
      return negative ? -9223372036854775808 : 9223372036854775807;
    }

    // Materialise at most 19 digits, preserving precision beyond double's range.
    final integerEnd = firstNonzero + integerDigits;
    final integer = digits
        .substring(
          firstNonzero,
          integerEnd < digits.length ? integerEnd : digits.length,
        )
        .padRight(integerDigits, '0');
    if (integerDigits == limit.length && integer.compareTo(limit) > 0) {
      return negative ? -9223372036854775808 : 9223372036854775807;
    }
    return int.parse(negative ? '-$integer' : integer);
  }

  static Color parseNonNullableColorBlack(Object? color) {
    return parseColor(color) ?? Colors.black;
  }

  static Color? parseColor(Object? color) {
    if (color == null) {
      return null;
    }

    if (color is String && color.startsWith('#')) {
      final hex = color.substring(1);

      int? hexColor;

      if (hex.length == 6) {
        hexColor = int.tryParse('FF$hex', radix: 16);
      } else if (hex.length == 8) {
        final rrggbb = hex.substring(0, 6);
        final aa = hex.substring(6, 8);
        hexColor = int.tryParse('$aa$rrggbb', radix: 16);
      }

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
      return dimension.isFinite ? dimension : null;
    }

    if (dimension is int) {
      return dimension.toDouble();
    }

    if (dimension is String) {
      final value = double.tryParse(dimension.replaceAll('px', ''));
      return value != null && value.isFinite ? value : null;
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
