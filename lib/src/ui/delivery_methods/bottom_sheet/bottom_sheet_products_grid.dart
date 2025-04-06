import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/products.dart';
import 'package:gravity_sdk/src/ui/widgets/product.dart';

import '../../../models/content.dart';
import '../../../models/element.dart';
import '../../../utils/element_utils.dart';
import '../../widgets/close_button.dart';

class BottomSheetProductsGrid extends StatelessWidget {
  final Content content;

  const BottomSheetProductsGrid({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final frameUi = content.variables.frameUI;
    final container = frameUi?.container;
    final close = frameUi?.close;
    final elements = content.variables.elements;
    final products = content.products;

    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: container != null
                ? EdgeInsets.only(
                    left: container.style.padding?.left ?? 0,
                    right: container.style.padding?.right ?? 0,
                    top: container.style.padding?.top ?? 0,
                    bottom: container.style.padding?.bottom ?? 0,
                  )
                : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment:
                  container?.style.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: elements.map(
                (e) {
                  if (e.type == GravityElementType.productsContainer) {
                    if (products == null) {
                      return const SizedBox.shrink();
                    }
                    return Expanded(
                      child: _ProductsGrid(
                        element: e,
                        products: products,
                      ),
                    );
                  } else {
                    return ElementUtils.getWidget(e);
                  }
                },
              ).toList(),
            ),
          ),
          if (close != null) GravityCloseButtonWidget(close: close)
        ],
      ),
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final GravityElement element;
  final Products products;

  const _ProductsGrid({
    super.key,
    required this.element,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.vertical,
      itemCount: products.slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final slot = products.slots[index];
        return GravityProductWidget(
          slot: slot,
        );
      },
    );
  }
}
