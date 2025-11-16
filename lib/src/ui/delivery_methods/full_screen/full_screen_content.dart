import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/utils/on_click_handler.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../elements/gravity_element.dart';
import '../../widgets/close_button.dart';

class FullScreenContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;

  const FullScreenContent({super.key, required this.content, required this.campaign});

  @override
  State<FullScreenContent> createState() => _FullScreenContentState();
}

class _FullScreenContentState extends State<FullScreenContent> {
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
    final elements = widget.content.variables.elements;
    final contentId = widget.content.contentId;
    final products = widget.content.products;

    final backgroundImage = container.style?.backgroundImage;
    final backgroundColor = container.style?.backgroundColor;
    final fit = container.style?.fit ?? BoxFit.cover;

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
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            if (backgroundImage != null) Positioned.fill(child: Image.network(backgroundImage, fit: fit)),
            SafeArea(
              bottom: false,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(
                      left: container.style?.padding?.left ?? 0,
                      right: container.style?.padding?.right ?? 0,
                      top: container.style?.padding?.top ?? 0,
                      bottom: container.style?.padding?.bottom ?? 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Column(
                                crossAxisAlignment:
                                    container.style?.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
                                mainAxisAlignment:
                                    container.style?.verticalAlignment?.toMainAxisAlignment() ?? MainAxisAlignment.center,
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
                          );
                        },
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
            ),
          ],
        ),
      ),
    );
  }
}
