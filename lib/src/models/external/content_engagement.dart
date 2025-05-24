import '../internal/campaign_content.dart';
import 'campaign.dart';

sealed class ContentEngagement {
  final CampaignContent content;
  final Campaign campaign;

  const ContentEngagement(this.content, this.campaign);
}

final class ContentImpressionEngagement extends ContentEngagement {
  const ContentImpressionEngagement(
    super.content,
    super.campaign,
  );
}

final class ContentVisibleImpressionEngagement extends ContentEngagement {
  const ContentVisibleImpressionEngagement(
    super.content,
    super.campaign,
  );
}

final class ContentCloseEngagement extends ContentEngagement {
  const ContentCloseEngagement(
    super.content,
    super.campaign,
  );
}
