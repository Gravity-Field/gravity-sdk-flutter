import 'package:flutter/material.dart';

import '../models/external/campaign.dart';
import '../models/internal/campaign_content.dart';
import '../models/internal/slot.dart';

abstract class ProductWidgetBuilder {
  const ProductWidgetBuilder();

  Widget build({
    required BuildContext context,
    required Slot product,
    required CampaignContent content,
    required final Campaign campaign,
  });
}
