import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_element.dart';
import '../../../models/content.dart';

class ModalFromContent extends StatelessWidget {
  final Content content;

  const ModalFromContent({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final frameUi = content.variables.frameUI!;
    final container = frameUi.container;
    final close = frameUi.close;
    final elements = content.variables.elements;
    final events = content.events;

    return Dialog(
      backgroundColor: container.style.backgroundColor ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(container.style.cornerRadius ?? 0),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: container.style.padding?.left ?? 0,
              top: container.style.padding?.top ?? 0,
              right: container.style.padding?.right ?? 0,
              bottom: container.style.padding?.bottom ?? 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: elements
                  .map(
                    (e) => GravityElement(element: e, events: events).getWidget(),
                  )
                  .toList(),
            ),
          ),
          if (close != null)
            Positioned(
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
            ),
        ],
      ),
    );
  }
}
