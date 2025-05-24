import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../../utils/on_click_handler.dart';
import '../../elements/gravity_element.dart';
import '../../widgets/close_button.dart';

class BottomSheetProductsRow extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const BottomSheetProductsRow({
    super.key,
    required this.content,
    required this.campaign,
  });

  @override
  State<BottomSheetProductsRow> createState() => _BottomSheetProductsRowState();
}

class _BottomSheetProductsRowState extends State<BottomSheetProductsRow> {
  late final OnClickHandler onClickHandler;

  @override
  void initState() {
    super.initState();

    onClickHandler = OnClickHandler(campaign: widget.campaign, content: widget.content);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ContentEventsService.instance.sendContentImpression(widget.content);
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameUi = widget.content.variables.frameUI;
    final container = frameUi?.container;
    final close = frameUi?.close;
    final elements = widget.content.variables.elements;
    final products = widget.content.products;
    final events = widget.content.events;
    final templateId = widget.content.templateId;

    return VisibilityDetector(
      key: ValueKey(templateId),
      onVisibilityChanged: (info) {
        var visiblePercentage = info.visibleFraction * 100;
        if (visiblePercentage >= 50) {
          ContentEventsService.instance.sendContentVisibleImpression(widget.content);
        }
      },
      child: SafeArea(
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
                children: elements
                    .map(
                      (e) => GravityElement(
                        element: e,
                        onClickCallback: (action) => onClickHandler.handeOnClick(action),
                        products: products,
                        campaign: widget.campaign,
                        content: widget.content,
                      ).getWidget(),
                    )
                    .toList(),
              ),
            ),
            if (close != null)
              GravityCloseButtonWidget(
                close: close,
                onClickCallback: (action) => onClickHandler.handeOnClick(action),
                // onClosePressed: () {
                //   ContentEventsService.instance.sendContentClosed(widget.content);
                // },
              )
          ],
        ),
      ),
    );
  }
}
