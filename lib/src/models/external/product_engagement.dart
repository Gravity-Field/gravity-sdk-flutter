import '../../../gravity_sdk.dart';

sealed class ProductEngagement {
  final Slot slot;
  final CampaignContent content;
  final Campaign campaign;

  const ProductEngagement(this.slot, this.content, this.campaign);
}

final class ProductClickEngagement extends ProductEngagement {
  const ProductClickEngagement(
    super.slot,
    super.content,
    super.campaign,
  );
}

final class ProductVisibleImpressionEngagement extends ProductEngagement {
  const ProductVisibleImpressionEngagement(
    super.slot,
    super.content,
    super.campaign,
  );
}
