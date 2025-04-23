import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_products_container.dart';

import '../models/element.dart';
import '../models/products.dart';
import '../ui/elements/gravity_button.dart';
import '../ui/elements/gravity_image.dart';
import '../ui/elements/gravity_text.dart';

class ElementUtils {
  static Widget getWidget(GravityElement element, {Products? products}) {
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
        if (products == null) {
          throw Exception('Products mast not be null when element type is products-container');
        }
        return GravityProductsContainer(element: element, products: products);
    }
  }
}
