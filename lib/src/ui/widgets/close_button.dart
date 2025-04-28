import 'package:flutter/material.dart' hide Element, Action;

import '../../models/internal/close.dart';
import '../../models/internal/action.dart';

class GravityCloseButtonWidget extends StatelessWidget {
  final Close close;
  final Function(Action) onAction;
  // final Function() onClosePressed;

  const GravityCloseButtonWidget({
    super.key,
    required this.close,
    required this.onAction,
    // required this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: close.style.positioned?.left,
      top: close.style.positioned?.top,
      right: close.style.positioned?.right,
      bottom: close.style.positioned?.bottom,
      child: IconButton(
        icon: close.image != null
            ? Image.network(close.image!, width: close.style.size?.width, height: close.style.size?.height)
            : Icon(Icons.close),
        onPressed: () {
          if (close.onClick != null) {
            onAction(close.onClick!);
          }
          // onClosePressed();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
