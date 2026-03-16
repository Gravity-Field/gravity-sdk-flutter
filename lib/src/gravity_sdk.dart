import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/src/models/internal/delivery_type.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content.dart';
import 'package:gravity_sdk/src/utils/product_events_service.dart';

import 'data/api/content_ids_response.dart';
import 'data/api/content_response.dart';
import 'models/external/gravity_data_response.dart';
import 'models/external/log_level.dart';
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
import 'data/error_reporting/error_helpers.dart';
import 'data/error_reporting/error_reporter.dart';
import 'utils/logger.dart';

typedef GravityEventCallback = void Function(TrackingEvent event);

/// Колбек, который вызывается с GravityDataResponse контента кампании.
/// Предназначен для использования в ручном (headless) режиме.
typedef GravityContentCallback = void Function(GravityDataResponse<ContentResponse> response);

class GravitySDK {
  //init fields
  String apiKey = '';
  String section = '';
  ProductWidgetBuilder? productWidgetBuilder;
  GravityEventCallback? gravityEventCallback;
  GravityContentCallback? gravityContentCallback;

  //other fields
  User? user;
  ContentSettings contentSettings = ContentSettings();
  Options options = Options();
  String? proxyUrl;
  bool isFetchContentOnTrack = true;
  NotificationPermissionStatus notificationPermissionStatus = NotificationPermissionStatus.unknown;

  GravitySDK._();

  static final GravitySDK instance = GravitySDK._();

  Future<void> initialize({
    required String apiKey,
    required String section,
    ProductWidgetBuilder? productWidgetBuilder,
    GravityEventCallback? gravityEventCallback,
    GravityContentCallback? gravityContentCallback,
    LogLevel logLevel = LogLevel.info,
  }) async {
    this.apiKey = apiKey;
    this.section = section;
    this.productWidgetBuilder = productWidgetBuilder;
    this.gravityEventCallback = gravityEventCallback;
    this.gravityContentCallback = gravityContentCallback;

    LoggerManager.instance.configure(logLevel);
  }

  void setOptions({
    Options? options,
    ContentSettings? contentSettings,
    String? proxyUrl,
    bool? isFetchContentOnTrack,
  }) {
    if (options != null) {
      this.options = options;
    }
    if (contentSettings != null) {
      this.contentSettings = contentSettings;
    }
    if (isFetchContentOnTrack != null) {
      this.isFetchContentOnTrack = isFetchContentOnTrack;
    }
    if (proxyUrl != null) {
      this.proxyUrl = proxyUrl;
    }
  }

  void setUser(String userId, String sessionId) {
    user = User(custom: userId, ses: sessionId);
  }

  void setNotificationPermissionStatus(NotificationPermissionStatus status) {
    notificationPermissionStatus = status;
  }

  Future<void> trackView({required BuildContext context, required PageContext pageContext}) async {
    _checkIsInitialized();
    try {
      final response = await GravityRepo.instance.visit(customUser: user, pageContext: pageContext, options: options);

      if (response.campaigns.isEmpty || !context.mounted) return;

      final resolved = await _resolveHighestPriority<ContentResponse>(
        campaigns: response.campaigns,
        pageContext: pageContext,
        fetchContent: (id, ctx) => getContentByCampaignId(campaignId: id, pageContext: ctx),
        extractCampaigns: (result) => result.data,
        section: 'GravitySDK.trackView',
      );
      if (resolved == null) return;

      final (result, campaignIdObj) = resolved;

      if (campaignIdObj.delayTime > 0) {
        await Future.delayed(Duration(milliseconds: campaignIdObj.delayTime));
      }

      if (!context.mounted) return;

      final campaign = result.data.first;
      _showBackendContent(context, campaign.payload.first.contents.first, campaign);
    } catch (e, stackTrace) {
      _reportError(e, stackTrace, section: 'GravitySDK.trackView');
    }
  }

  Future<void> triggerEvent({
    required BuildContext context,
    required List<TriggerEvent> events,
    required PageContext pageContext,
  }) async {
    _checkIsInitialized();
    try {
      final response = await GravityRepo.instance.event(
        events: events,
        customUser: user,
        pageContext: pageContext,
        options: options,
      );

      if (response.campaigns.isEmpty || !context.mounted) return;

      final resolved = await _resolveHighestPriority<ContentResponse>(
        campaigns: response.campaigns,
        pageContext: pageContext,
        fetchContent: (id, ctx) => getContentByCampaignId(campaignId: id, pageContext: ctx),
        extractCampaigns: (result) => result.data,
        section: 'GravitySDK.triggerEvent',
      );
      if (resolved == null) return;

      final (result, campaignIdObj) = resolved;

      if (campaignIdObj.delayTime > 0) {
        await Future.delayed(Duration(milliseconds: campaignIdObj.delayTime));
      }

      if (!context.mounted) return;

      final campaign = result.data.first;
      _showBackendContent(context, campaign.payload.first.contents.first, campaign);
    } catch (e, stackTrace) {
      _reportError(e, stackTrace, section: 'GravitySDK.triggerEvent');
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
        ContentEventsService.instance.sendContentClosed(
          content: engagement.content,
          campaign: engagement.campaign,
          callbackTrackingEvent: false,
        );
    }
  }

  Future<void> triggerTrackingUrl(String url) async {
    await GravityRepo.instance.triggerEventUrls([url]);
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

  Future<ContentResponse> getContentBySelector({required String selector, required PageContext pageContext}) async {
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

  Future<ContentResponse> getContentByCampaignId({required String campaignId, required PageContext pageContext}) async {
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

  Future<ContentResponse> getContentByGroup({required String group, required PageContext pageContext}) async {
    _checkIsInitialized();

    final content = await GravityRepo.instance.getContentByGroup(
      group: group,
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

  /// Запрашивает контент по селектору и возвращает объект с моделью и исходным JSON.
  Future<GravityDataResponse<ContentResponse>> getContentBySelectorWithDetails({
    required String selector,
    required PageContext pageContext,
  }) async {
    _checkIsInitialized();

    final response = await GravityRepo.instance.getContentBySelectorWithDetails(
      selector: selector,
      pageContext: pageContext,
      options: options,
      contentSetting: contentSettings,
    );

    for (final campaign in response.data.data) {
      for (final payload in campaign.payload) {
        for (final content in payload.contents) {
          ContentEventsService.instance.sendContentLoaded(content: content, campaign: campaign);
        }
      }
    }

    gravityContentCallback?.call(response);

    return response;
  }

  Future<GravityDataResponse<ContentResponse>> getContentByCampaignIdWithDetails({
    required String campaignId,
    required PageContext pageContext,
  }) async {
    _checkIsInitialized();

    final response = await GravityRepo.instance.getContentByCampaignIdWithDetails(
      campaignId: campaignId,
      pageContext: pageContext,
      options: options,
      contentSetting: contentSettings,
    );

    for (final campaign in response.data.data) {
      for (final payload in campaign.payload) {
        for (final content in payload.contents) {
          ContentEventsService.instance.sendContentLoaded(content: content, campaign: campaign);
        }
      }
    }

    gravityContentCallback?.call(response);

    return response;
  }

  /// Отслеживает просмотр экрана и, если кампания активирована,
  /// получает и возвращает ее контент в виде сырого JSON.
  ///
  /// Возвращает GravityDataResponse или `null`, если кампания не сработала.
  /// Также вызывает [gravityContentCallback] в случае успеха.
  Future<GravityDataResponse<ContentResponse>?> trackViewNoShow({required PageContext pageContext}) async {
    _checkIsInitialized();
    try {
      final response = await GravityRepo.instance.visit(customUser: user, pageContext: pageContext, options: options);

      if (response.campaigns.isEmpty || !isFetchContentOnTrack) return null;

      return await _resolveHighestPriorityNoShow(
        campaigns: response.campaigns,
        pageContext: pageContext,
      );
    } catch (e, stackTrace) {
      _reportError(e, stackTrace, section: 'GravitySDK.trackViewNoShow');
      return null;
    }
  }

  /// Отправляет событие и, если кампания активирована,
  /// получает и возвращает ее контент в виде сырого JSON.
  ///
  /// Возвращает GravityDataResponse или `null`, если кампания не сработала.
  /// Также вызывает [gravityContentCallback] в случае успеха.
  Future<GravityDataResponse<ContentResponse>?> triggerEventNoShow({
    required List<TriggerEvent> events,
    required PageContext pageContext,
  }) async {
    _checkIsInitialized();
    try {
      final response = await GravityRepo.instance.event(
        events: events,
        customUser: user,
        pageContext: pageContext,
        options: options,
      );

      if (response.campaigns.isEmpty || !isFetchContentOnTrack) return null;

      return await _resolveHighestPriorityNoShow(
        campaigns: response.campaigns,
        pageContext: pageContext,
      );
    } catch (e, stackTrace) {
      _reportError(e, stackTrace, section: 'GravitySDK.triggerEventNoShow');
      return null;
    }
  }

  /// Sorts [campaigns] by priority (descending) and iterates through them,
  /// calling [fetchContent] for each until one returns a campaign with
  /// non-empty content. Returns the fetch result paired with the matching
  /// [CampaignId], or `null` if no campaign yielded content.
  Future<(T, CampaignId)?> _resolveHighestPriority<T>({
    required List<CampaignId> campaigns,
    required PageContext pageContext,
    required Future<T> Function(String campaignId, PageContext pageContext) fetchContent,
    required List<Campaign> Function(T result) extractCampaigns,
    required String section,
  }) async {
    final sorted = List.of(campaigns)..sort((a, b) => b.priority.compareTo(a.priority));

    for (final campaignId in sorted) {
      try {
        final result = await fetchContent(campaignId.campaignId, pageContext);
        final campaign = extractCampaigns(result).firstOrNull;
        if (campaign == null) continue;

        final content = campaign.payload.firstOrNull?.contents.firstOrNull;
        if (content == null) continue;

        return (result, campaignId);
      } catch (e, stackTrace) {
        _reportError(
          e,
          stackTrace,
          section: section,
          extra: {'campaignId': campaignId.campaignId, 'priority': campaignId.priority},
        );
      }
    }
    return null;
  }

  /// Resolves the highest-priority campaign in headless (NoShow) mode,
  /// returning the detailed response or `null` if no campaign yielded content.
  Future<GravityDataResponse<ContentResponse>?> _resolveHighestPriorityNoShow({
    required List<CampaignId> campaigns,
    required PageContext pageContext,
  }) async {
    final resolved = await _resolveHighestPriority<GravityDataResponse<ContentResponse>>(
      campaigns: campaigns,
      pageContext: pageContext,
      fetchContent: (campaignId, ctx) => getContentByCampaignIdWithDetails(campaignId: campaignId, pageContext: ctx),
      extractCampaigns: (result) => result.data.data,
      section: 'GravitySDK._resolveHighestPriorityNoShow',
    );

    return resolved?.$1;
  }

  void _reportError(
    Object error,
    StackTrace stackTrace, {
    required String section,
    Map<String, Object>? extra,
  }) {
    ErrorReporter.instance.report(
      message: error.toString(),
      level: errorLevel(error),
      section: section,
      stacktrace: stackTrace.toString(),
      extra: extra,
      tags: {'category': categorizeError(error)},
    );
  }

  void _showBackendContent(BuildContext context, CampaignContent content, Campaign campaign) {
    try {
      switch (content.deliveryMethod) {
        case DeliveryMethod.modal:
          _showModalContent(context, content, campaign);
        case DeliveryMethod.bottomSheet:
          _showBottomSheetContent(context, content, campaign);
        case DeliveryMethod.fullScreen:
          _showFullScreenContent(context, content, campaign);
        case DeliveryMethod.snackBar:
          _showSnackBar(context, content, campaign);
        case DeliveryMethod.json:
          break;
        default:
      }
    } catch (e, stackTrace) {
      ErrorReporter.instance.report(
        message: e.toString(),
        level: 'error',
        section: 'GravitySDK._showBackendContent',
        stacktrace: stackTrace.toString(),
        extra: {'deliveryMethod': content.deliveryMethod.name},
        tags: {'category': 'ui'},
      );
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
        backgroundColor: container.style?.backgroundColor,
        isScrollControlled: true,
        useSafeArea: true,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(container.style?.cornerRadius ?? 0),
            topRight: Radius.circular(container.style?.cornerRadius ?? 0),
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

    final snackBar = SnackBarContent.getSnackBar(
      template: template,
      content: content,
      campaign: campaign,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar.toMaterialSnackBar(context));
    }
  }

  void _checkIsInitialized() {
    if (apiKey.isEmpty || section.isEmpty) {
      throw Exception('GravitySDK is not initialized. Call initialize() first.');
    }
  }
}
