import 'package:flutter/material.dart';

import '../models/internal/slot.dart';
import '../ui/widgets/product.dart';

abstract class ProductWidgetBuilder {
  const ProductWidgetBuilder();

  Widget build(Slot product, BuildContext context);
}

class DefaultProductWidgetBuilder implements ProductWidgetBuilder {
  const DefaultProductWidgetBuilder();

  @override
  Widget build(Slot product, BuildContext context) {
    return GravityProductWidget(
      slot: product,
    );
  }
}
