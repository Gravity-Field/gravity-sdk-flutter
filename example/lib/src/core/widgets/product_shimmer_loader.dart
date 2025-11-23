import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProductsShimmerLoader extends StatelessWidget {
  final bool showTitle;
  final int itemCount;
  final double itemWidth;
  final EdgeInsets padding;
  final EdgeInsets? titleMargin;

  const ProductsShimmerLoader({
    super.key,
    this.showTitle = true,
    this.itemCount = 3,
    this.itemWidth = 164,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.titleMargin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle)
          Padding(
            padding: titleMargin ?? const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        SizedBox(
          height: 260,
          child: ListView.separated(
            padding: padding,
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ProductShimmerItem(
              width: itemWidth,
            ),
          ),
        ),
      ],
    );
  }
}

class ProductShimmerItem extends StatelessWidget {
  final double width;

  const ProductShimmerItem({
    super.key,
    this.width = 164,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: width,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: width * 0.9,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: width * 0.7,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: width * 0.6,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
