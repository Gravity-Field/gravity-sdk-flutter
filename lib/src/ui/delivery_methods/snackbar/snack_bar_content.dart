import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content_1.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import 'snack_bar_content_2.dart';

abstract class SnackBarContent {
  SnackBarContent();

  SnackBar toMaterialSnackBar();

  factory SnackBarContent.getSnackBar({
    required TemplateSystemName template,
    required CampaignContent content,
    required Campaign campaign,
  }) {
    return switch (template) {
      TemplateSystemName.snackbar1 => SnackBarContent1(campaign: campaign, content: content),
      TemplateSystemName.snackbar2 => SnackBarContent2(campaign: campaign, content: content),
      TemplateSystemName.unknown => throw UnimplementedError(),
    };
  }
}
