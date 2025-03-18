import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_element.dart';

import '../../../models/content.dart';

class ModalFromContent extends StatelessWidget {
  final Content content;

  const ModalFromContent({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final frameUi = content.variables.frameUI;
    final container = frameUi.container;
    final elements = content.variables.elements;

    return Dialog(
      backgroundColor: container.style.color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(container.style.cornerRadius ?? 0),
      ),
      child: Stack(
        children: [
          Padding(
            padding:  EdgeInsets.only(
              left: container.style.padding?.left ?? 0,
              right: container.style.padding?.right ?? 0,
              top: container.style.padding?.top ?? 0,
              bottom: container.style.padding?.bottom ?? 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: elements
                  .map(
                    (e) => GravityElementWidget(element: e),
                  )
                  .toList(),
            ),
          ),
          // Positioned(
          //   top: 12,
          //   right: 12,
          //   child: IconButton(
          //     icon: Icon(Icons.close),
          //     onPressed: () {
          //       Navigator.of(context).pop();
          //     },
          //   ),
          // ),
        ],
      ),
    );
  }
}
