import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/internal/campaign_content.dart';
import 'package:gravity_sdk/src/models/internal/element.dart';
import 'package:gravity_sdk/src/utils/content_events_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/external/campaign.dart';
import '../../../utils/on_click_handler.dart';
import '../../elements/gravity_element.dart';
import '../../widgets/close_button.dart';

class BottomSheetContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const BottomSheetContent({super.key, required this.content, required this.campaign});

  @override
  State<BottomSheetContent> createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<BottomSheetContent> {
  late final OnClickHandler onClickHandler;

  @override
  void initState() {
    super.initState();

    onClickHandler = OnClickHandler(campaign: widget.campaign, content: widget.content);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ContentEventsService.instance.sendContentImpression(campaign: widget.campaign, content: widget.content);
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameUi = widget.content.variables.frameUI!;
    final container = frameUi.container;
    final close = frameUi.close;
    final elements = widget.content.variables.elements;
    final contentId = widget.content.contentId;
    final products = widget.content.products;

    return VisibilityDetector(
      key: ValueKey(contentId),
      onVisibilityChanged: (info) {
        var visiblePercentage = info.visibleFraction * 100;
        if (visiblePercentage >= 50) {
          ContentEventsService.instance
              .sendContentVisibleImpression(campaign: widget.campaign, content: widget.content);
        }
      },
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(container.style?.cornerRadius ?? 0),
            topRight: Radius.circular(container.style?.cornerRadius ?? 0),
          ),
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: container.style?.padding?.left ?? 0,
                  right: container.style?.padding?.right ?? 0,
                  top: container.style?.padding?.top ?? 0,
                  bottom: container.style?.padding?.bottom ?? 0,
                ),
                child: Column(
                  crossAxisAlignment:
                      container.style?.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: elements
                      .map(
                        (e) => GravityElement(
                          element: e,
                          content: widget.content,
                          campaign: widget.campaign,
                          products: products,
                          onClickCallback: (action) {
                            if (e.type == ElementType.button && action.closeOnClick) {
                              Navigator.of(context).pop();
                            }
                            onClickHandler.handeOnClick(action);
                          },
                        ).getWidget(),
                      )
                      .toList(),
                ),
              ),
              if (close != null)
                GravityCloseButtonWidget(
                  close: close,
                  onClickCallback: (action) {
                    onClickHandler.handeOnClick(action);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
