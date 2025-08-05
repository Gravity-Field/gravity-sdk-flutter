import 'package:collection/collection.dart';

import '../../gravity_sdk.dart';
import '../models/actions/product_action.dart';
import '../models/external/campaign.dart';
import '../models/internal/campaign_content.dart';
import '../repos/gravity_repo.dart';

class ProductEventsService {
  ProductEventsService._();

  static final ProductEventsService instance = ProductEventsService._();

  void sendProductClick({
    required Slot slot,
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    _trackEvent(action: ProductAction.pclick, slot: slot, content: content, campaign: campaign);
  }

  void sendProductVisibleImpression({
    required Slot slot,
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    _trackEvent(action: ProductAction.pimp, slot: slot, content: content, campaign: campaign);
  }

  void _trackEvent({
    required ProductAction action,
    required Slot slot,
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final event = slot.events?.firstWhereOrNull((event) => event.type == action);

    if (event == null) return;

    final urls = event.urls;

    GravityRepo.instance.triggerEventUrls(urls);

    if (callbackTrackingEvent) {
      final event = switch (action) {
        ProductAction.pimp => ProductImpressionEvent(slot, content, campaign),
        _ => null,
      };
      if (event != null) {
        GravitySDK.instance.gravityEventCallback?.call(event);
      }
    }
  }
}
