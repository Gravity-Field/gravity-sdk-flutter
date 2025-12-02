import '../../../gravity_sdk.dart';

sealed class TrackingEvent {
  final Campaign campaign;

  const TrackingEvent(this.campaign);
}

class ContentLoadEvent extends TrackingEvent {
  final CampaignContent content;

  ContentLoadEvent(this.content, Campaign campaign) : super(campaign);
}

class ContentImpressionEvent extends TrackingEvent {
  final CampaignContent content;

  ContentImpressionEvent(this.content, Campaign campaign) : super(campaign);
}

class ContentVisibleImpressionEvent extends TrackingEvent {
  final CampaignContent content;

  ContentVisibleImpressionEvent(this.content, Campaign campaign) : super(campaign);
}

class ContentCloseEvent extends TrackingEvent {
  final CampaignContent content;

  ContentCloseEvent(this.content, Campaign campaign) : super(campaign);
}

class CopyEvent extends TrackingEvent {
  final String copiedValue;
  final CampaignContent content;

  CopyEvent(this.copiedValue, this.content, Campaign campaign) : super(campaign);
}

class CancelEvent extends TrackingEvent {
  final CampaignContent content;

  CancelEvent(this.content, Campaign campaign) : super(campaign);
}

class FollowUrlEvent extends TrackingEvent {
  final String url;
  final CampaignContent content;

  FollowUrlEvent(this.url, this.content, Campaign campaign) : super(campaign);
}

class FollowDeeplinkEvent extends TrackingEvent {
  final String deeplink;
  final CampaignContent content;

  FollowDeeplinkEvent(this.deeplink, this.content, Campaign campaign) : super(campaign);
}

class RequestPushEvent extends TrackingEvent {
  final CampaignContent content;

  RequestPushEvent(this.content, Campaign campaign) : super(campaign);
}

class ProductImpressionEvent extends TrackingEvent {
  final Slot slot;
  final CampaignContent content;

  ProductImpressionEvent(this.slot, this.content, Campaign campaign) : super(campaign);
}
