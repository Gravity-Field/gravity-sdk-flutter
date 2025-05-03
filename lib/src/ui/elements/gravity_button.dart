import 'package:flutter/material.dart' hide Action, Element;
import 'package:gravity_sdk/src/models/actions/on_click.dart';

import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

class GravityButton extends StatelessWidget {
  final Element element;
  final Function(OnClick onClick) onClickCallback;

  const GravityButton({
    super.key,
    required this.element,
    required this.onClickCallback,
  });

  @override
  Widget build(BuildContext context) {
    final style = element.style!;
    final textStyle = style.textStyle;
    final layoutWidth = style.layoutWidth;
    final onClick = element.onClick;

    final buttonWidget = FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(style.backgroundColor),
        overlayColor: WidgetStateProperty.all(style.pressColor),
        fixedSize: WidgetStateProperty.all(Size.fromHeight(style.size?.height ?? 48)),
      ),
      onPressed: onClick != null
          ? () {
              onClickCallback(onClick);
            }
          : null,
      child: Text(
        element.text ?? '',
        style: TextStyle(
          color: textStyle?.color,
          fontSize: textStyle?.fontSize,
          fontWeight: textStyle?.fontWeight,
        ),
      ),
    );

    Widget outputWidget = buttonWidget;

    if (layoutWidth == GravityLayoutWidth.matchParent) {
      outputWidget = Row(
        children: [
          Expanded(
            child: outputWidget,
          ),
        ],
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

    return outputWidget;
  }
}
