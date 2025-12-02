import 'package:collection/collection.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';

class ContentEventsService {
  ContentEventsService._();

  static final ContentEventsService instance = ContentEventsService._();

  void sendContentLoaded({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onLoad = content.variables.onLoad;
    _trackEvent(
      action: onLoad,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendContentImpression({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onImpression = content.variables.onImpression;
    _trackEvent(
      action: onImpression,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendContentVisibleImpression({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onVisibleImpression = content.variables.onVisibleImpression;
    _trackEvent(
      action: onVisibleImpression,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendContentClosed({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onClose = content.variables.onClose;
    _trackEvent(
      action: onClose,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void _trackEvent({
    required ContentAction? action,
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    if (action == null) return;

    final event = content.events?.firstWhereOrNull((event) => event.type == action.action);

    if (event == null) return;

    final urls = event.urls;

    GravityRepo.instance.triggerEventUrls(urls);

    if (callbackTrackingEvent) {
      final event = switch (action.action) {
        Action.load => ContentLoadEvent(content, campaign),
        Action.impression => ContentImpressionEvent(content, campaign),
        Action.visibleImpression => ContentVisibleImpressionEvent(content, campaign),
        Action.close => ContentCloseEvent(content, campaign),
        _ => null,
      };

      if (event != null) {
        GravitySDK.instance.gravityEventCallback?.call(event);
      }
    }
  }
}
