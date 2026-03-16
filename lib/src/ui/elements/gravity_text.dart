import 'package:flutter/material.dart' hide Element;

import '../../models/actions/on_click.dart';
import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

class GravityText extends StatelessWidget {
  final Element element;
  final Function(OnClick onClick)? onClickCallback;

  const GravityText({super.key, required this.element, this.onClickCallback});

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
      style: TextStyle(color: style.textColor, fontSize: style.fontSize, fontWeight: style.fontWeight),
    );
    Widget outputWidget = textWidget;

    outputWidget = SizedBox(
      width: style.layoutWidth == GravityLayoutWidth.wrapContent ? null : double.infinity,
      child: outputWidget,
    );

    if (style.padding != null) {
      outputWidget = Padding(
        padding: EdgeInsets.only(
          left: style.padding!.left,
          right: style.padding!.right,
          top: style.padding!.top,
          bottom: style.padding!.bottom,
        ),
        child: outputWidget,
      );
    }

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

    final onClick = element.onClick;
    if (onClick != null && onClickCallback != null) {
      outputWidget = GestureDetector(
        onTap: () => onClickCallback!(onClick),
        child: outputWidget,
      );
    }

    return outputWidget;
  }
}
