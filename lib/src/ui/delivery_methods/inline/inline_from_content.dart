import 'package:flutter/material.dart';

import '../../../models/content.dart';
import '../../../utils/element_utils.dart';

class InlineFromContent extends StatelessWidget {
  final Content content;

  const InlineFromContent({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final frameUi = content.variables.frameUI!;
    final container = frameUi.container;
    final elements = content.variables.elements;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(container.style.cornerRadius ?? 0),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: container.style.padding?.left ?? 0,
          right: container.style.padding?.right ?? 0,
          top: container.style.padding?.top ?? 0,
          bottom: container.style.padding?.bottom ?? 0,
        ),
        child: Column(
          crossAxisAlignment: container.style.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: elements
              .map(
                (e) => ElementUtils.getWidget(e),
              )
              .toList(),
        ),
      ),
    );
  }
}
