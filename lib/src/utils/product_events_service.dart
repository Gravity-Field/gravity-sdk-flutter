import 'package:collection/collection.dart';

import '../../gravity_sdk.dart';
import '../models/actions/product_action.dart';
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
    _trackEvent(
      action: ProductAction.click,
      slot: slot,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendProductVisibleImpression({
    required Slot slot,
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    _trackEvent(
      action: ProductAction.visibleImpression,
      slot: slot,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
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
        ProductAction.visibleImpression => ProductImpressionEvent(slot, content, campaign),
        _ => null,
      };
      if (event != null) {
        GravitySDK.instance.gravityEventCallback?.call(event);
      }
    }
  }
}
