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

/// Click on content rendered by the app. Not for SDK-rendered content: its
/// buttons already report the click.
final class ContentClickEngagement extends ContentEngagement {
  const ContentClickEngagement(
    super.content,
    super.campaign,
  );
}
