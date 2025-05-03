import 'package:flutter/material.dart' hide Element, Action;
import 'package:gravity_sdk/src/models/actions/on_click.dart';

import '../../models/internal/element.dart';
import '../../models/internal/products.dart';
import 'gravity_button.dart';
import 'gravity_image.dart';
import 'gravity_products_container.dart';
import 'gravity_text.dart';

class GravityElement {
  final Element element;
  final Function(OnClick) onClickCallback;
  final Products? products;

  GravityElement({
    required this.element,
    required this.onClickCallback,
    this.products,
  });

  Widget getWidget() {
    switch (element.type) {
      case ElementType.image:
        return GravityImageWidget(element: element);
      case ElementType.text:
        return GravityText(element: element);
      case ElementType.button:
        return GravityButton(
          element: element,
          onClickCallback: onClickCallback,
        );
      case ElementType.spacer:
        return Spacer();
      case ElementType.unknown:
        return SizedBox.shrink();
      case ElementType.productsContainer:
        if (products == null) {
          throw Exception('Products mast not be null when element type is products-container');
        }
        return GravityProductsContainer(
          element: element,
          products: products!,
        );
    }
  }
}
