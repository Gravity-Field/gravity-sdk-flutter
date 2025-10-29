import 'package:flutter/material.dart' hide Element;
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/utils/product_events_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/external/campaign.dart';
import '../../models/internal/campaign_content.dart';
import '../../models/internal/element.dart';
import '../../models/internal/product_container_type.dart';
import '../../models/internal/products.dart';

class GravityProductsContainer extends StatefulWidget {
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
  State<GravityProductsContainer> createState() => _GravityProductsContainerState();
}

class _GravityProductsContainerState extends State<GravityProductsContainer> {
  final Set<String> _visibleProductIds = {};

  @override
  Widget build(BuildContext context) {
    final slots = widget.products.slots;

    if (slots == null) {
      return SizedBox(height: widget.element.style?.size?.height);
    }

    final productContainerType = widget.element.style?.productContainerType ?? ProductContainerType.row;

    if (productContainerType == ProductContainerType.grid) {
      return _buildGridLayout(slots);
    } else {
      return _buildRowLayout(slots);
    }
  }

  Widget _buildRowLayout(List<Slot> slots) {
    return SizedBox(
      height: widget.element.style?.size?.height,
      child: ListView.separated(
        padding: widget.element.style?.padding != null
            ? EdgeInsets.only(
                left: widget.element.style!.padding!.left,
                right: widget.element.style!.padding!.right,
                top: widget.element.style!.padding!.top,
                bottom: widget.element.style!.padding!.bottom,
              )
            : const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        itemBuilder: (context, index) {
          return _buildProductItem(context, slots[index]);
        },
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
      ),
    );
  }

  Widget _buildGridLayout(List<Slot> slots) {
    final gridSettings = widget.element.style?.gridSettings;
    final columns = gridSettings?.columnsCount ?? 2;
    final horizontalSpacing = gridSettings?.horizontalSpacingValue ?? 8.0;
    final verticalSpacing = gridSettings?.verticalSpacingValue ?? 8.0;

    return Padding(
      padding: widget.element.style?.padding != null
          ? EdgeInsets.only(
              left: widget.element.style!.padding!.left,
              right: widget.element.style!.padding!.right,
              top: widget.element.style!.padding!.top,
              bottom: widget.element.style!.padding!.bottom,
            )
          : EdgeInsets.zero,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: horizontalSpacing,
          mainAxisSpacing: verticalSpacing,
          childAspectRatio: widget.element.style?.size?.width != null && widget.element.style?.size?.height != null
              ? widget.element.style!.size!.width! / widget.element.style!.size!.height!
              : 1.0,
        ),
        itemCount: slots.length,
        itemBuilder: (context, index) {
          return _buildProductItem(context, slots[index]);
        },
      ),
    );
  }

  Widget _buildProductItem(BuildContext context, Slot slot) {
    final productBuilder = GravitySDK.instance.productWidgetBuilder;

    if (productBuilder == null) {
      return SizedBox.shrink();
    }

    final productWidget = productBuilder.build(
      context: context,
      product: slot,
      content: widget.content,
      campaign: widget.campaign,
    );

    return VisibilityDetector(
      key: ValueKey(slot.slotId),
      onVisibilityChanged: (info) {
        final slotId = slot.slotId;
        if (slotId == null || _visibleProductIds.contains(slotId)) return;

        var visiblePercentage = info.visibleFraction * 100;
        if (visiblePercentage >= 50) {
          _visibleProductIds.add(slotId);
          ProductEventsService.instance.sendProductVisibleImpression(
            slot: slot,
            content: widget.content,
            campaign: widget.campaign,
          );
        }
      },
      child: productWidget,
    );
  }
}
