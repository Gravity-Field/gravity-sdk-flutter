import 'package:flutter/material.dart' hide Element;

import '../../models/actions/on_click.dart';
import '../../models/internal/element.dart';
import '../../models/internal/style.dart';

class GravityImageWidget extends StatelessWidget {
  final Element element;
  final Function(OnClick onClick)? onClickCallback;

  const GravityImageWidget({
    super.key,
    required this.element,
    this.onClickCallback,
  });

  @override
  Widget build(BuildContext context) {
    final style = element.style!;
    final layoutWidth = style.layoutWidth;
    final onClick = element.onClick;

    Widget outputWidget = Image.network(
      element.src ?? '',
      fit: style.fit ?? BoxFit.cover,
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

    if (style.cornerRadius != null && style.cornerRadius! > 0) {
      outputWidget = ClipRRect(
        borderRadius: BorderRadius.circular(style.cornerRadius!),
        child: outputWidget,
      );
    }

    if (layoutWidth == GravityLayoutWidth.matchParent) {
      outputWidget = SizedBox(
        width: double.infinity,
        child: outputWidget,
      );
    }

    outputWidget = SizedBox(
      height: style.size?.height,
      width: style.size?.width,
      child: outputWidget,
    );

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
      onTap: onClick != null && onClickCallback != null
          ? () {
              onClickCallback!(onClick);
            }
          : null,
      child: outputWidget,
    );
  }
}
