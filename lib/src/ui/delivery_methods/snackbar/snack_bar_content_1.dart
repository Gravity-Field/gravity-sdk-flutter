import 'package:flutter/material.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../models/internal/element.dart';
import 'snack_bar_content.dart';

class SnackBarContent1 extends SnackBarContent {
  final CampaignContent content;
  final Campaign campaign;

  SnackBarContent1({
    required this.content,
    required this.campaign,
  });

  @override
  SnackBar toMaterialSnackBar() {
    final frameUi = content.variables.frameUI!;
    final container = frameUi.container;
    final style = container.style;
    final padding = style.padding;
    final elements = content.variables.elements;
    final texts = elements.where((element) => element.type == ElementType.text);
    final images = elements.where((element) => element.type == ElementType.image);


    return SnackBar(
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.all(12),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      content: Row(
        children: [

        ],
      ),
    );
  }
}
