import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/src/models/internal/delivery_type.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content.dart';
import 'package:gravity_sdk/src/utils/product_events_service.dart';

import 'data/api/content_response.dart';
import 'models/external/campaign.dart';
import 'models/external/content_engagement.dart';
import 'models/external/content_settings.dart';
import 'models/external/notification_permission_status.dart';
import 'models/external/options.dart';
import 'models/external/page_context.dart';
import 'models/external/product_engagement.dart';
import 'models/external/tracking_event.dart';
import 'models/external/trigger_event.dart';
import 'models/external/user.dart';
import 'models/internal/campaign_content.dart';
import 'repos/gravity_repo.dart';
import 'settings/product_widget_builder.dart';
import 'ui/delivery_methods/bottom_sheet/bottom_sheet_content.dart';
import 'ui/delivery_methods/full_screen/full_screen_content.dart';
import 'ui/delivery_methods/modal/modal_content.dart';
import 'utils/content_events_service.dart';

typedef GravityEventCallback = void Function(TrackingEvent event);

class GravitySDK {
  //init fields
  String apiKey = '';
  String section = '';
  ProductWidgetBuilder? productWidgetBuilder;
  GravityEventCallback? gravityEventCallback;


  //other fields
  User? user;
  ContentSettings contentSettings = ContentSettings();
  Options options = Options();
  String? proxyUrl;
  NotificationPermissionStatus notificationPermissionStatus = NotificationPermissionStatus.unknown;

  GravitySDK._();

  static final GravitySDK instance = GravitySDK._();

  Future<void> initialize({
    required String apiKey,
    required String section,
    ProductWidgetBuilder? productWidgetBuilder,
    GravityEventCallback? gravityEventCallback,
  }) async {
    this.apiKey = apiKey;
    this.section = section;
    this.productWidgetBuilder = productWidgetBuilder;
    this.gravityEventCallback = gravityEventCallback;
  }

  void setOptions({
    Options? options,
    ContentSettings? contentSettings,
    String? proxyUrl,
  }) {
    if (options != null) {
      this.options = options;
    }
    if (contentSettings != null) {
      this.contentSettings = contentSettings;
    }
    this.proxyUrl = proxyUrl;
  }

  void setUser(String userId, String sessionId) {
    user = User(
      custom: userId,
      ses: sessionId,
    );
  }

  void setNotificationPermissionStatus(NotificationPermissionStatus status) {
    notificationPermissionStatus = status;
  }

  Future<void> trackView({required BuildContext context, required PageContext pageContext}) async {
    _checkIsInitialized();
    final response = await GravityRepo.instance.visit(customUser: user, pageContext: pageContext, options: options);
    final campaignId = response.campaigns.firstOrNull;
    if (campaignId != null) {
      final result = await getContentByCampaignId(campaignId: campaignId.campaignId, pageContext: pageContext);
      final campaign = result.data.firstOrNull;
      if (campaign != null) {
        final content = campaign.payload.firstOrNull?.contents.firstOrNull;
        if (content != null) {
          _showBackendContent(context, content, campaign);
        }
      }
    }
  }

  Future<void> triggerEvent(
      {required BuildContext context, required List<TriggerEvent> events, required PageContext pageContext}) async {
    _checkIsInitialized();
    final response =
        await GravityRepo.instance.event(events: events, customUser: user, pageContext: pageContext, options: options);
    final campaignId = response.campaigns.firstOrNull;
    if (campaignId != null) {
      final result = await getContentByCampaignId(campaignId: campaignId.campaignId, pageContext: pageContext);
      final campaign = result.data.firstOrNull;
      if (campaign != null) {
        final content = campaign.payload.firstOrNull?.contents.firstOrNull;
        if (content != null) {
          _showBackendContent(context, content, campaign);
        }
      }
    }
  }

  void sendContentEngagement(ContentEngagement engagement) {
    _checkIsInitialized();
    switch (engagement) {
      case ContentImpressionEngagement():
        ContentEventsService.instance.sendContentImpression(
          content: engagement.content,
          campaign: engagement.campaign,
          callbackTrackingEvent: false,
        );
      case ContentVisibleImpressionEngagement():
        ContentEventsService.instance.sendContentVisibleImpression(
          content: engagement.content,
          campaign: engagement.campaign,
          callbackTrackingEvent: false,
        );
      case ContentCloseEngagement():
        ContentEventsService.instance.sendContentVisibleImpression(
          content: engagement.content,
          campaign: engagement.campaign,
          callbackTrackingEvent: false,
        );
    }
  }

  void sendProductEngagement(ProductEngagement engagement) {
    _checkIsInitialized();

    switch (engagement) {
      case ProductClickEngagement():
        ProductEventsService.instance.sendProductClick(
          slot: engagement.slot,
          content: engagement.content,
          campaign: engagement.campaign,
          callbackTrackingEvent: false,
        );

      case ProductVisibleImpressionEngagement():
        ProductEventsService.instance.sendProductVisibleImpression(
          slot: engagement.slot,
          content: engagement.content,
          campaign: engagement.campaign,
          callbackTrackingEvent: false,
        );
    }
  }

  Future<ContentResponse> getContentBySelector({required String selector, PageContext? pageContext}) async {
    _checkIsInitialized();

    final content = await GravityRepo.instance.getContentBySelector(
      selector: selector,
      pageContext: pageContext,
      options: options,
      contentSetting: contentSettings,
    );

    for (final campaign in content.data) {
      for (final payload in campaign.payload) {
        for (final content in payload.contents) {
          ContentEventsService.instance.sendContentLoaded(content: content, campaign: campaign);
        }
      }
    }

    return content;
  }

  Future<ContentResponse> getContentByCampaignId({required String campaignId, PageContext? pageContext}) async {
    _checkIsInitialized();

    final content = await GravityRepo.instance.getContentByCampaignId(
      campaignId: campaignId,
      pageContext: pageContext,
      options: options,
      contentSetting: contentSettings,
    );

    for (final campaign in content.data) {
      for (final payload in campaign.payload) {
        for (final content in payload.contents) {
          ContentEventsService.instance.sendContentLoaded(content: content, campaign: campaign);
        }
      }
    }

    return content;
  }

  void _showBackendContent(BuildContext context, CampaignContent content, Campaign campaign) {
    switch (content.deliveryMethod) {
      case DeliveryMethod.modal:
        _showModalContent(context, content, campaign);
      case DeliveryMethod.bottomSheet:
        _showBottomSheetContent(context, content, campaign);
      case DeliveryMethod.fullScreen:
        _showFullScreenContent(context, content, campaign);
      case DeliveryMethod.snackBar:
        _showSnackBar(context, content, campaign);
      default:
    }
  }

  void _showModalContent(BuildContext context, CampaignContent content, Campaign campaign) {
    if (context.mounted) {
      final modal = ModalContent(content: content, campaign: campaign);

      showDialog(
        context: context,
        builder: (context) {
          return modal;
        },
      );
    }
  }

  void _showBottomSheetContent(BuildContext context, CampaignContent content, Campaign campaign) {
    if (context.mounted) {
      final bottomSheet = BottomSheetContent(content: content, campaign: campaign);

      final frameUi = content.variables.frameUI!;
      final container = frameUi.container;

      showModalBottomSheet(
        backgroundColor: container.style.backgroundColor,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(container.style.cornerRadius ?? 0),
            topRight: Radius.circular(container.style.cornerRadius ?? 0),
          ),
        ),
        context: context,
        builder: (context) {
          return bottomSheet;
        },
      );
    }
  }

  void _showFullScreenContent(BuildContext context, CampaignContent content, Campaign campaign) {
    if (context.mounted) {
      final fullScreen = FullScreenContent(content: content, campaign: campaign);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return fullScreen;
          },
        ),
      );
    }
  }

  void _showSnackBar(BuildContext context, CampaignContent content, Campaign campaign) {
    final template = content.templateSystemName;

    if (template == null || template == TemplateSystemName.unknown) {
      return;
    }

    final snackBar = SnackBarContent.getSnackBar(template: template, content: content, campaign: campaign);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar.toMaterialSnackBar());
    }
  }

  void _checkIsInitialized() {
    if (apiKey.isEmpty || section.isEmpty) {
      throw Exception('GravitySDK is not initialized. Call initialize() first.');
    }
  }
}
