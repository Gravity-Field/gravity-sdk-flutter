import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_button.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_image.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_text.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../models/internal/element.dart';
import '../../../utils/on_click_handler.dart';
import 'snack_bar_content.dart';

class SnackBarContent2 extends SnackBarContent {
  final CampaignContent content;
  final Campaign campaign;

  late final OnClickHandler onClickHandler;

  SnackBarContent2({
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
    final image = elements.firstWhereOrNull((element) => element.type == ElementType.image);
    final button = elements.firstWhereOrNull((element) => element.type == ElementType.button);

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
            if (image != null) ...[
              GravityImageWidget(
                element: image,
                onClickCallback: (action) => onClickHandler.handeOnClick(action, context),
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (texts.elementAtOrNull(0) != null)
                    GravityText(
                      element: texts.elementAt(0),
                      onClickCallback: (action) => onClickHandler.handeOnClick(action, context),
                    ),
                  if (texts.elementAtOrNull(1) != null) ...[
                    SizedBox(height: 4),
                    GravityText(
                      element: texts.elementAt(1),
                      onClickCallback: (action) => onClickHandler.handeOnClick(action, context),
                    ),
                  ],
                  if (button != null) ...[
                    SizedBox(height: 12),
                    GravityButton(
                      element: button,
                      onClickCallback: (action) {
                        onClickHandler.handeOnClick(action, context);
                        if (action.closeOnClick) {
                          onDismiss?.call();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
