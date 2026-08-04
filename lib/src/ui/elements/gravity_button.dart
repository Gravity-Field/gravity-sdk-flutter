import 'package:flutter/material.dart' hide Action, Element;
import 'package:gravity_sdk/src/models/actions/on_click.dart';

import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

class GravityButton extends StatelessWidget {
  final Element element;
  final Function(OnClick onClick) onClickCallback;
  final bool enabled;

  const GravityButton({
    super.key,
    required this.element,
    required this.onClickCallback,
    this.enabled = true,
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

        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          return style.backgroundColor;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          return textStyle?.color;
        }),
        overlayColor: WidgetStateProperty.all(style.pressColor),
        minimumSize: style.size?.height != null ? WidgetStateProperty.all(Size(0, style.size!.height!)) : null,
        shape: WidgetStateProperty.resolveWith<RoundedRectangleBorder>((
          states,
        ) {
          var outlineColor = style.outlineColor;
          if (outlineColor != null && states.contains(WidgetState.disabled)) {
            outlineColor = outlineColor.withValues(alpha: 0.4);
          }
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.cornerRadius ?? 8),
            side: outlineColor == null ? BorderSide.none : BorderSide(color: outlineColor),
          );
        }),
      ),
      onPressed: enabled && onClick != null
          ? () {
              onClickCallback(onClick);
            }
          : null,
      child: Text(
        element.text ?? '',
        style: TextStyle(
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
