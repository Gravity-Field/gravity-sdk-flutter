import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/style.dart';

import '../../models/element.dart';

class GravityText extends StatelessWidget {
  final GravityElement element;

  const GravityText({super.key, required this.element});

  @override
  Widget build(BuildContext context) {
    final style = element.style!;

    final textAlign = switch (style.contentAlignment) {
      null => null,
      GravityContentAlignment.start => TextAlign.start,
      GravityContentAlignment.center => TextAlign.center,
      GravityContentAlignment.end => TextAlign.end,
    };

    final textWidget = Text(
      element.text ?? '',
      textAlign: textAlign,
      style: TextStyle(
        color: style.textColor,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
      ),
    );
    Widget outputWidget = textWidget;

    if (style.margin != null) {
      outputWidget = Padding(
        padding: EdgeInsets.only(
          left: style.margin!.left,
          right: style.margin!.right,
          top: style.margin!.top,
          bottom: style.margin!.bottom,
        ),
        child: outputWidget,
      );
    }

    return outputWidget;
  }
}
