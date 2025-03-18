import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_button.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_text.dart';

import '../../models/element.dart';
import 'gravity_image.dart';

class GravityElementWidget extends StatelessWidget {
  final GravityElement element;
  const GravityElementWidget({super.key, required this.element});

  @override
  Widget build(BuildContext context) {
    switch (element.type) {
      case GravityElementType.image:
        return GravityImageWidget(element: element);
      case GravityElementType.text:
        return GravityText(element: element);
      case GravityElementType.button:
        return GravityButton(element: element);
      case GravityElementType.unknown:
        return SizedBox.shrink();
    }
  }
}
