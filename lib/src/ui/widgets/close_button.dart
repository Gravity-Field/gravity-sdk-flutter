import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/close.dart';

class GravityCloseButtonWidget extends StatelessWidget {
  final Close close;

  const GravityCloseButtonWidget({super.key, required this.close});

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
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
