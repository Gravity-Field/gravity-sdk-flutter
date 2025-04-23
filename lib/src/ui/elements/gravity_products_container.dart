import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';

import '../../models/element.dart';
import '../../models/products.dart';

class GravityProductsContainer extends StatelessWidget {
  final GravityElement element;
  final Products products;

  const GravityProductsContainer({super.key, required this.element, required this.products});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: element.style?.size?.height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: products.slots.length,
        itemBuilder: (context, index) {
          final slot = products.slots[index];
          return GravitySDK.instance.productWidgetBuilder.build(slot, context);
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
