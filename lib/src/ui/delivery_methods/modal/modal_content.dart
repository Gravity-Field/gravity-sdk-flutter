import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_element.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../widgets/close_button.dart';

class ModalContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const ModalContent({super.key, required this.content, required this.campaign});

  @override
  State<ModalContent> createState() => _ModalContentState();
}

class _ModalContentState extends State<ModalContent> {
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
    final frameUi = widget.content.variables.frameUI!;
    final container = frameUi.container;
    final close = frameUi.close;
    final elements = widget.content.variables.elements ?? [];
    final contentId = widget.content.contentId;
    final products = widget.content.products;

    final backgroundImage = container.style?.backgroundImage;
    final backgroundColor = container.style?.backgroundColor ?? Colors.white;
    final fit = container.style?.fit ?? BoxFit.cover;
    final cornerRadius = container.style?.cornerRadius ?? 0;

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
      child: Dialog(
        backgroundColor: backgroundImage != null ? Colors.transparent : backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cornerRadius)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (backgroundImage != null)
              Positioned.fill(
                child: Image.network(
                  backgroundImage,
                  fit: fit,
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: container.style?.padding?.left ?? 0,
                top: container.style?.padding?.top ?? 0,
                right: container.style?.padding?.right ?? 0,
                bottom: container.style?.padding?.bottom ?? 0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: elements
                      .map(
                        (e) => GravityElement(
                          element: e,
                          campaign: widget.campaign,
                          content: widget.content,
                          products: products,
                          onClickCallback: (action) => onClickHandler.handeOnClick(action),
                        ).getWidget(),
                      )
                      .toList(),
                ),
              ),
            ),
            if (close != null)
              GravityCloseButtonWidget(
                close: close,
                onClickCallback: (action) => onClickHandler.handeOnClick(action),
                // onClosePressed: () {
                //   ContentEventsService.instance.sendContentClosed(widget.content);
                // },
              ),
          ],
        ),
      ),
    );
  }
}
