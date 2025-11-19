import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../elements/gravity_element.dart';

class InlineContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const InlineContent({super.key, required this.content, required this.campaign});

  @override
  State<InlineContent> createState() => _InlineContentState();
}

class _InlineContentState extends State<InlineContent> {
  late final OnClickHandler onClickHandler;
  bool _hasBeenVisible = false;

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
    final frameUi = widget.content.variables.frameUI;
    final container = frameUi?.container;
    final elements = widget.content.variables.elements;
    final products = widget.content.products;
    final contentId = widget.content.contentId;

    final backgroundImage = container?.style?.backgroundImage;
    final backgroundColor = container?.style?.backgroundColor;
    final fit = container?.style?.fit ?? BoxFit.cover;
    final cornerRadius = container?.style?.cornerRadius ?? 0;

    return VisibilityDetector(
      key: ValueKey(contentId),
      onVisibilityChanged: (info) {
        if (_hasBeenVisible) return;

        var visiblePercentage = info.visibleFraction * 100;
        if (visiblePercentage >= 50) {
          _hasBeenVisible = true;
          ContentEventsService.instance.sendContentVisibleImpression(
            campaign: widget.campaign,
            content: widget.content,
          );
        }
      },
      child: Container(
        height: container?.style?.size?.height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(cornerRadius),
          image: backgroundImage != null ? DecorationImage(image: NetworkImage(backgroundImage), fit: fit) : null,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: container?.style?.padding?.left ?? 0,
            right: container?.style?.padding?.right ?? 0,
            top: container?.style?.padding?.top ?? 0,
            bottom: container?.style?.padding?.bottom ?? 0,
          ),
          child: Column(
            crossAxisAlignment: container?.style?.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: elements
                .map(
                  (e) => GravityElement(
                    element: e,
                    onClickCallback: (action) => onClickHandler.handeOnClick(action),
                    campaign: widget.campaign,
                    content: widget.content,
                    products: products,
                  ).getWidget(),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
