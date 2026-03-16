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
        padding: WidgetStateProperty.all(
          style.padding != null
              ? EdgeInsets.only(
                  left: style.padding?.left ?? 0,
                  right: style.padding?.right ?? 0,
                  top: style.padding?.top ?? 0,
                  bottom: style.padding?.bottom ?? 0,
                )
              : EdgeInsets.zero,
        ),
        backgroundColor: WidgetStateProperty.all(style.backgroundColor),
        overlayColor: WidgetStateProperty.all(style.pressColor),
        minimumSize: style.size?.height != null ? WidgetStateProperty.all(Size(0, style.size!.height!)) : null,
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.cornerRadius ?? 8),
          ),
        ),
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
          Expanded(child: outputWidget),
        ],
      );
    }

    if (style.margin != null) {
      outputWidget = Padding(
        padding: EdgeInsets.only(
          left: style.margin?.left ?? 0,
          right: style.margin?.right ?? 0,
          top: style.margin?.top ?? 0,
          bottom: style.margin?.bottom ?? 0,
        ),
        child: outputWidget,
      );
    }

    return outputWidget;
  }
}
