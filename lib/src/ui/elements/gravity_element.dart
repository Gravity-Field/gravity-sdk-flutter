import 'package:flutter/material.dart' hide Element, Action;
import 'package:collection/collection.dart';

import '../../models/element.dart';
import '../../models/event.dart';
import '../../models/products.dart';
import '../../models/action.dart';
import '../../repos/gravity_repo.dart';
import 'gravity_button.dart';
import 'gravity_image.dart';
import 'gravity_products_container.dart';
import 'gravity_text.dart';

class GravityElement {
  final Element element;
  final List<Event> events;
  final Products? products;

  GravityElement({
    required this.element,
    required this.events,
    this.products,
  });

  void _onAction(Action action) {
    final event = events.firstWhereOrNull((element) => element.name == action.action);
    if (event != null) {
      GravityRepo.instance.triggerEventUrls(event.urls);
    }
  }

  Widget getWidget() {
    switch (element.type) {
      case ElementType.image:
        return GravityImageWidget(element: element);
      case ElementType.text:
        return GravityText(element: element);
      case ElementType.button:
        return GravityButton(
          element: element,
          onAction: _onAction,
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
