import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_image.dart';
import 'package:gravity_sdk/src/ui/elements/gravity_text.dart';

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
  SnackBar toMaterialSnackBar(BuildContext context) {
    final frameUi = content.variables.frameUI!;
    final container = frameUi.container;
    final style = container.style;
    final padding = style?.padding;
    final elements = content.variables.elements ?? [];
    final texts = elements.where((element) => element.type == ElementType.text);
    final images = elements.where((element) => element.type == ElementType.image);
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        bottom: screenHeight - topPadding - 250,
        left: 16,
        right: 16,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: container.onClick != null
            ? () {
                onClickHandler.handeOnClick(container.onClick!);
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
                GravityImageWidget(element: images.first),
                SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (texts.elementAtOrNull(0) != null) GravityText(element: texts.elementAt(0)),
                    if (texts.elementAtOrNull(1) != null) ...[
                      SizedBox(height: 4),
                      GravityText(element: texts.elementAt(1)),
                    ],
                  ],
                ),
              ),
              if (images.elementAtOrNull(1) != null) ...[
                SizedBox(width: 8),
                GravityImageWidget(element: images.elementAt(1)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
