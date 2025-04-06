import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/products.dart';
import 'package:gravity_sdk/src/ui/widgets/product.dart';

import '../../../models/content.dart';
import '../../../models/element.dart';
import '../../../utils/element_utils.dart';
import '../../widgets/close_button.dart';

class BottomSheetProductsRow extends StatelessWidget {
  final Content content;

  const BottomSheetProductsRow({
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
                    return _ProductsRow(
                      element: e,
                      products: products,
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

class _ProductsRow extends StatelessWidget {
  final GravityElement element;
  final Products products;

  const _ProductsRow({
    super.key,
    required this.element,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: products.slots.length,
        itemBuilder: (context, index) {
          final slot = products.slots[index];
          return GravityProductWidget(
            slot: slot,
          );
        },
        separatorBuilder: (context, index) {
          return const SizedBox(
            width: 8,
          );
        },
      ),
    );
  }
}
