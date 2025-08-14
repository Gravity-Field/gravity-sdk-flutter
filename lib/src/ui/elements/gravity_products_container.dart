import 'package:flutter/material.dart' hide Element;
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/utils/product_events_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/external/campaign.dart';
import '../../models/internal/campaign_content.dart';
import '../../models/internal/element.dart';
import '../../models/internal/products.dart';

class GravityProductsContainer extends StatelessWidget {
  final Element element;
  final Products products;
  final Campaign campaign;
  final CampaignContent content;

  const GravityProductsContainer({
    super.key,
    required this.element,
    required this.products,
    required this.campaign,
    required this.content,
  });

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

          final productBuilder = GravitySDK.instance.productWidgetBuilder;

          if (productBuilder == null) {
            return SizedBox.shrink();
          }

          final productWidget = productBuilder.build(
            context: context,
            product: slot,
            content: content,
            campaign: campaign,
          );

          return VisibilityDetector(
            key: ValueKey(slot.slotId),
            onVisibilityChanged: (info) {
              var visiblePercentage = info.visibleFraction * 100;
              if (visiblePercentage >= 50) {
                ProductEventsService.instance.sendProductVisibleImpression(
                  slot: slot,
                  content: content,
                  campaign: campaign,
                );
              }
            },
            child: productWidget,
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
