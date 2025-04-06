import 'package:flutter/material.dart';

import '../models/element.dart';
import '../ui/elements/gravity_button.dart';
import '../ui/elements/gravity_image.dart';
import '../ui/elements/gravity_text.dart';

class ElementUtils {
  static Widget getWidget(GravityElement element) {
    switch (element.type) {
      case GravityElementType.image:
        return GravityImageWidget(element: element);
      case GravityElementType.text:
        return GravityText(element: element);
      case GravityElementType.button:
        return GravityButton(element: element);
      case GravityElementType.spacer:
        return Spacer();
      case GravityElementType.unknown:
        return SizedBox.shrink();
      case GravityElementType.productsContainer:
        throw Exception('ProductContainer should be handled in the delivery method widget');
    }
  }
}
