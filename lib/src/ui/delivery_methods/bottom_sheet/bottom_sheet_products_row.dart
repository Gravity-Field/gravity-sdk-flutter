import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/settings/product_widget_builder.dart';

import '../../../models/content.dart';
import '../../../models/element.dart';
import '../../../utils/element_utils.dart';
import '../../widgets/close_button.dart';

class BottomSheetProductsRow extends StatelessWidget {
  final Content content;
  final ProductWidgetBuilder productWidgetBuilder;

  const BottomSheetProductsRow({
    super.key,
    required this.content,
    required this.productWidgetBuilder,
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
                    return SizedBox(
                      height: e.style?.size?.height,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: products.slots.length,
                        itemBuilder: (context, index) {
                          final slot = products.slots[index];
                          return productWidgetBuilder.build(slot, context);
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(
                            width: 8,
                          );
                        },
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
