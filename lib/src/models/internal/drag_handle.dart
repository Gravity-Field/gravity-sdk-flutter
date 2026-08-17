import 'package:flutter/material.dart';

import 'style.dart';

/// The grabber of a bottom sheet, a sibling of `close` and `arrow` inside
/// `frameUI`. It is chrome around the content, not part of it, so it carries
/// its own style rather than living in `container.style`.
///
/// Parsed tolerantly: nothing above [FrameUI] catches parsing errors, so a
/// malformed handle must degrade instead of taking the whole `/choose`
/// response down with it.
class DragHandle {
  final Style style;

  const DragHandle({required this.style});

  /// Returns null — meaning "no handle" — unless the payload carries a style
  /// object with `visible: true`, mirroring the `close: null` convention.
  /// A visible handle whose styling is unusable falls back to the defaults:
  /// the flag states the intent, broken values must not swallow the element.
  static DragHandle? tryParse(Object? json) {
    if (json is! Map) return null;
    final rawStyle = json['style'];
    if (rawStyle is! Map || rawStyle['visible'] != true) return null;

    try {
      return DragHandle(style: Style.fromJson(Map<String, dynamic>.from(rawStyle)));
    } catch (_) {
      return DragHandle(style: Style());
    }
  }

  Color get color => style.backgroundColor ?? const Color(0xFFD9D9D9);

  double get width => _dimension(style.size?.width, 36);

  double get height => _dimension(style.size?.height, 4);

  double get cornerRadius => _dimension(style.cornerRadius, height / 2);

  EdgeInsets get margin {
    final margin = style.margin;
    if (margin == null) return const EdgeInsets.only(top: 18, bottom: 4);
    return EdgeInsets.only(
      left: margin.left,
      right: margin.right,
      top: margin.top,
      bottom: margin.bottom,
    );
  }

  /// Negative, zero, NaN and infinite values would reach layout as-is and
  /// trip BoxConstraints asserts, so anything non-positive is unusable.
  static double _dimension(double? value, double fallback) {
    if (value == null || !value.isFinite || value <= 0) return fallback;
    return value;
  }
}
