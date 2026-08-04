import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/widgets/gravity_elements_column.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../models/internal/element.dart';
import '../../../utils/on_click_handler.dart';
import 'snack_bar_content.dart';

class SnackBarContent1 extends SnackBarContent {
  final CampaignContent content;
  final Campaign campaign;

  late final OnClickHandler onClickHandler;

  SnackBarContent1({
    required this.content,
    required this.campaign,
  }) {
    onClickHandler = OnClickHandler(content: content, campaign: campaign);
  }

  @override
  Widget buildContent(BuildContext context, {VoidCallback? onDismiss}) {
    final frameUi = content.variables.frameUI!;
    final container = frameUi.container;
    final style = container.style;
    final padding = style?.padding;
    final elements = content.variables.elements ?? [];
    final texts = elements.where((element) => element.type == ElementType.text);
    final images = elements.where((element) => element.type == ElementType.image);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: container.onClick != null
          ? () {
              onClickHandler.handeOnClick(container.onClick!, context);
            }
          : null,
      child: Container(
        padding: EdgeInsets.only(
          left: padding?.left ?? 0,
          top: padding?.top ?? 0,
          right: padding?.right ?? 0,
          bottom: padding?.bottom ?? 0,
        ),
        decoration: BoxDecoration(
          color: container.style?.backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(style?.cornerRadius ?? 0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            if (images.isNotEmpty) ...[
              GravityElementsColumn(
                content: content,
                campaign: campaign,
                elements: [images.first],
                formsEnabled: false,
                onClickCallback: (element, action) {
                  onClickHandler.handeOnClick(action, context);
                  if (shouldAutoCloseOnClick(action)) {
                    onDismiss?.call();
                  }
                },
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (texts.elementAtOrNull(0) != null)
                    GravityElementsColumn(
                      content: content,
                      campaign: campaign,
                      elements: [texts.elementAt(0)],
                      formsEnabled: false,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      onClickCallback: (element, action) =>
                          onClickHandler.handeOnClick(action, context),
                    ),
                  if (texts.elementAtOrNull(1) != null) ...[
                    SizedBox(height: 4),
                    GravityElementsColumn(
                      content: content,
                      campaign: campaign,
                      elements: [texts.elementAt(1)],
                      formsEnabled: false,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      onClickCallback: (element, action) =>
                          onClickHandler.handeOnClick(action, context),
                    ),
                  ],
                ],
              ),
            ),
            if (images.elementAtOrNull(1) != null) ...[
              SizedBox(width: 8),
              GravityElementsColumn(
                content: content,
                campaign: campaign,
                elements: [images.elementAt(1)],
                formsEnabled: false,
                onClickCallback: (element, action) {
                  onClickHandler.handeOnClick(action, context);
                  if (shouldAutoCloseOnClick(action)) {
                    onDismiss?.call();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
