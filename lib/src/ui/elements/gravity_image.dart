import 'package:flutter/material.dart';

import '../../models/element.dart';

class GravityImageWidget extends StatelessWidget {
  final GravityElement element;

  const GravityImageWidget({super.key, required this.element});

  @override
  Widget build(BuildContext context) {
    final style = element.style;

    final imageWidget = Image.network(
      element.src ?? '',
      fit: style.fit,
    );
    Widget outputWidget = imageWidget;

    if (style.size != null) {
      outputWidget = SizedBox(
        width: style.size!.width,
        height: style.size!.height,
        child: imageWidget,
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
