import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/utils/content_events_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/content.dart';
import '../../../utils/element_events_handler.dart';
import '../../elements/gravity_element.dart';
import '../../widgets/close_button.dart';

class BottomSheetFromContent extends StatefulWidget {
  final Content content;

  const BottomSheetFromContent({super.key, required this.content});

  @override
  State<BottomSheetFromContent> createState() => _BottomSheetFromContentState();
}

class _BottomSheetFromContentState extends State<BottomSheetFromContent> {
  late final ElementEventsHandler eventsHandler;

  @override
  void initState() {
    super.initState();

    eventsHandler = ElementEventsHandler(widget.content.events);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ContentEventsService.instance.sendContentImpression(widget.content);
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameUi = widget.content.variables.frameUI!;
    final container = frameUi.container;
    final close = frameUi.close;
    final elements = widget.content.variables.elements;
    final isBanner = widget.content.contentType == 'banner';
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
        child: ClipRRect(
          borderRadius: isBanner
              ? BorderRadius.only(
                  topLeft: Radius.circular(container.style.cornerRadius ?? 0),
                  topRight: Radius.circular(container.style.cornerRadius ?? 0),
                )
              : BorderRadius.zero,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: container.style.padding?.left ?? 0,
                  right: container.style.padding?.right ?? 0,
                  top: container.style.padding?.top ?? 0,
                  bottom: container.style.padding?.bottom ?? 0,
                ),
                child: Column(
                  crossAxisAlignment:
                      container.style.contentAlignment?.toCrossAxisAlignment() ?? CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: elements
                      .map(
                        (e) => GravityElement(
                          element: e,
                          onAction: (action) {
                            eventsHandler.handleAction(action);
                          },
                        ).getWidget(),
                      )
                      .toList(),
                ),
              ),
              if (close != null)
                GravityCloseButtonWidget(
                  close: close,
                  onAction: (action) {
                    eventsHandler.handleAction(action);
                  },
                  // onClosePressed: () {
                  //   ContentEventsService.instance.sendContentClosed(widget.content);
                  // },
                )
            ],
          ),
        ),
      ),
    );
  }
}
