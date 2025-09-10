import 'package:flutter/material.dart' hide Element, Action;
import 'package:gravity_sdk/src/models/actions/on_click.dart';

import '../../models/actions/close.dart';



class GravityCloseButtonWidget extends StatelessWidget {
  final Close close;
  final Function(OnClick) onClickCallback;
  // final Function() onClosePressed;

  const GravityCloseButtonWidget({
    super.key,
    required this.close,
    required this.onClickCallback,
    // required this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: close.style?.positioned?.left,
      top: close.style?.positioned?.top,
      right: close.style?.positioned?.right,
      bottom: close.style?.positioned?.bottom,
      child: IconButton(
        icon: close.image != null
            ? Image.network(close.image!, width: close.style?.size?.width, height: close.style?.size?.height)
            : Icon(Icons.close),
        onPressed: () {
          if (close.onClick != null) {
            onClickCallback(close.onClick!);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
