import 'package:flutter/material.dart';

import '../../../models/content.dart';
import '../../../utils/content_events_service.dart';
import '../../../utils/element_events_handler.dart';
import '../../elements/gravity_element.dart';

class InlineFromContent extends StatefulWidget {
  final Content content;

  const InlineFromContent({super.key, required this.content});

  @override
  State<InlineFromContent> createState() => _InlineFromContentState();
}

class _InlineFromContentState extends State<InlineFromContent> {
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
                  onAction: (action) => eventsHandler.handleAction(action),
                ).getWidget(),
              )
              .toList(),
        ),
      ),
    );
  }
}
