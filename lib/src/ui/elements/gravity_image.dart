import 'package:flutter/material.dart' hide Element;

import '../../models/actions/on_click.dart';
import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

class GravityImageWidget extends StatelessWidget {
  final Element element;
  final Function(OnClick onClick) onClickCallback;

  const GravityImageWidget({
    super.key,
    required this.element,
    required this.onClickCallback,
  });

  @override
  Widget build(BuildContext context) {
    final style = element.style!;
    final layoutWidth = style.layoutWidth;
    final onClick = element.onClick;

    final imageWidget = Image.network(
      element.src ?? '',
      fit: style.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );

    Widget outputWidget = imageWidget;

    if (style.size != null) {
      outputWidget = ClipRRect(
        borderRadius: BorderRadius.circular(style.cornerRadius ?? 0),
        child: SizedBox(
          width: layoutWidth == GravityLayoutWidth.matchParent ? double.infinity : style.size!.width,
          height: style.size!.height,
          child: imageWidget,
        ),
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

    return GestureDetector(
      onTap: onClick != null
          ? () {
              onClickCallback(onClick);
            }
          : null,
      child: outputWidget,
    );
  }
}
