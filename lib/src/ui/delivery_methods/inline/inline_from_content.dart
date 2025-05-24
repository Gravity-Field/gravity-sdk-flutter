import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../elements/gravity_element.dart';

class InlineFromContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const InlineFromContent({super.key, required this.content, required this.campaign});

  @override
  State<InlineFromContent> createState() => _InlineFromContentState();
}

class _InlineFromContentState extends State<InlineFromContent> {
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
    final frameUi = widget.content.variables.frameUI;
    final container = frameUi?.container;
    final elements = widget.content.variables.elements;
    final products = widget.content.products;
    final events = widget.content.events;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(container?.style.cornerRadius ?? 0),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: container?.style.padding?.left ?? 0,
          right: container?.style.padding?.right ?? 0,
          top: container?.style.padding?.top ?? 0,
          bottom: container?.style.padding?.bottom ?? 0,
        ),
        child: Column(
          crossAxisAlignment: container?.style.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: elements
              .map(
                (e) => GravityElement(
                  element: e,
                  products: products,
                  onClickCallback: (action) => onClickHandler.handeOnClick(action),
                  campaign: widget.campaign,
                  content: widget.content,
                ).getWidget(),
              )
              .toList(),
        ),
      ),
    );
  }
}
