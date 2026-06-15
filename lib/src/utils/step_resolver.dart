import '../models/external/campaign.dart';
import '../models/internal/campaign_content.dart';

/// Finds the step content in a campaign payload whose [CampaignContent.step]
/// equals [step]. Searches across all variations. Returns the first match, or
/// `null` if [step] is null or no content matches.
CampaignContent? resolveStepContent(Campaign campaign, int? step) {
  if (step == null) return null;
  for (final variation in campaign.payload) {
    for (final content in variation.contents) {
      if (content.step == step) return content;
    }
  }
  return null;
}

/// Selects the root content (the one without a `step`) from [contents].
/// Returns `null` if there is no root content (the list is empty or every
/// content is a step). A step content is never returned as root.
CampaignContent? resolveRootContent(List<CampaignContent> contents) {
  for (final content in contents) {
    if (content.step == null) return content;
  }
  return null;
}
