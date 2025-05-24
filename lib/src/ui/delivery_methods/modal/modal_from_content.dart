import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_element.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../widgets/close_button.dart';

class ModalFromContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const ModalFromContent({super.key, required this.content, required this.campaign});

  @override
  State<ModalFromContent> createState() => _ModalFromContentState();
}

class _ModalFromContentState extends State<ModalFromContent> {
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
    final events = widget.content.events;
    final templateId = widget.content.templateId;

    return VisibilityDetector(
      key: ValueKey(templateId),
      onVisibilityChanged: (info) {
        var visiblePercentage = info.visibleFraction * 100;
        if (visiblePercentage >= 50) {
          ContentEventsService.instance.sendContentVisibleImpression(campaign: widget.campaign, content: widget.content);
        }
      },
      child: Dialog(
        backgroundColor: container.style.backgroundColor ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(container.style.cornerRadius ?? 0),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: container.style.padding?.left ?? 0,
                top: container.style.padding?.top ?? 0,
                right: container.style.padding?.right ?? 0,
                bottom: container.style.padding?.bottom ?? 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: elements
                    .map(
                      (e) => GravityElement(
                        element: e,
                        campaign: widget.campaign,
                        content: widget.content,
                        onClickCallback: (action) => onClickHandler.handeOnClick(action),
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
