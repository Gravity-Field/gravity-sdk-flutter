import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/src/utils/product_events_service.dart';

import 'data/api/content_response.dart';
import 'models/external/content_engagement.dart';
import 'models/external/content_settings.dart';
import 'models/external/options.dart';
import 'models/external/page_context.dart';
import 'models/external/product_engagement.dart';
import 'models/external/tracking_event.dart';
import 'models/external/trigger_event.dart';
import 'models/external/user.dart';
import 'models/internal/device.dart';
import 'repos/gravity_repo.dart';
import 'settings/product_widget_builder.dart';
import 'ui/delivery_methods/bottom_sheet/bottom_sheet_from_content.dart';
import 'ui/delivery_methods/bottom_sheet/bottom_sheet_products_row.dart';
import 'ui/delivery_methods/full_screen/full_screen_from_content.dart';
import 'ui/delivery_methods/modal/modal_from_content.dart';
import 'utils/content_events_service.dart';
import 'utils/device_utils.dart';

typedef GravityEventCallback = void Function(TrackingEvent event);

class GravitySDK {
  //init fields
  String apiKey = '';
  String section = '';
  ProductWidgetBuilder productWidgetBuilder = DefaultProductWidgetBuilder();
  GravityEventCallback? gravityEventCallback;

  //other fields
  User? user;
  late Device device;
  ContentSettings contentSettings = ContentSettings();
  Options options = Options();
  String? proxyUrl;

  GravitySDK._();

  static final GravitySDK instance = GravitySDK._();


  Future<void> initialize({
    required String apiKey,
    required String section,
    ProductWidgetBuilder? productWidgetBuilder,
    GravityEventCallback? gravityEventCallback,
    bool useAdvertisingId = false,
  }) async {
    this.apiKey = apiKey;
    this.section = section;
    this.productWidgetBuilder = productWidgetBuilder ?? DefaultProductWidgetBuilder();
    this.gravityEventCallback = gravityEventCallback;

    final userAgent = await DeviceUtils.getUserAgent();
    final deviceIdentifier = await DeviceUtils.getDeviceId(useAdvertisingId);

    device = Device(
      userAgent: userAgent,
      id: deviceIdentifier,
    );
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

  Future<void> trackView({required PageContext pageContext}) async {
    _checkIsInitialized();
    await GravityRepo.instance.visit(customUser: user, pageContext: pageContext, options: options);
  }

  Future<void> triggerEvent({required List<TriggerEvent> events, required PageContext pageContext}) async {
    _checkIsInitialized();
    await GravityRepo.instance.event(events: events, customUser: user, pageContext: pageContext, options: options);
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

  Future<ContentResponse> getContent(String template) async {
    _checkIsInitialized();

    final content =
        await GravityRepo.instance.getContent(templateId: template, options: options, contentSetting: contentSettings);

    for (final campaign in content.data) {
      for (final payload in campaign.payload) {
        for (final content in payload.contents) {
          ContentEventsService.instance.sendContentLoaded(content: content, campaign: campaign);
        }
      }
    }

    return content;
  }

  void showModalContent(BuildContext context, ContentResponse contentResponse) {
    final campaign = contentResponse.data.first;
    final content = campaign.payload.first.contents.first;

    if (context.mounted) {
      final modal = ModalFromContent(content: content, campaign: campaign);

      showDialog(
        context: context,
        builder: (context) {
          return modal;
        },
      );
    }
  }

  void showBottomSheetContent(BuildContext context, ContentResponse contentResponse) {
    final campaign = contentResponse.data.first;
    final content = campaign.payload.first.contents.first;

    if (context.mounted) {
      final bottomSheet = BottomSheetFromContent(content: content, campaign: campaign);

      final frameUi = content.variables.frameUI!;
      final container = frameUi.container;

      showModalBottomSheet(
        backgroundColor: container.style.backgroundColor,
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

  void showFullScreenContent(BuildContext context, ContentResponse contentResponse) {
    final campaign = contentResponse.data.first;
    final content = campaign.payload.first.contents.first;

    if (context.mounted) {
      final fullScreen = FullScreenFromContent(content: content, campaign: campaign);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return fullScreen;
          },
        ),
      );
    }
  }

  void showBottomSheetProductsRow(BuildContext context, ContentResponse contentResponse) {
    final campaign = contentResponse.data.first;
    final content = campaign.payload.first.contents.first;

    if (context.mounted) {
      final bottomSheet = BottomSheetProductsRow(content: content, campaign: campaign);

      final frameUi = content.variables.frameUI;
      final container = frameUi?.container;

      showModalBottomSheet(
        backgroundColor: container?.style.backgroundColor,
        shape: container != null
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(container.style.cornerRadius ?? 0),
                  topRight: Radius.circular(container.style.cornerRadius ?? 0),
                ),
              )
            : null,
        context: context,
        builder: (context) {
          return bottomSheet;
        },
      );
    }
  }

  void _checkIsInitialized() {
    if (apiKey.isEmpty || section.isEmpty) {
      throw Exception('GravitySDK is not initialized. Call initialize() first.');
    }
  }

// void _showSnackBar(BuildContext context) {
//   final snackBarType = SnackBarType.type1;
//   final snackBarData = SnackBarData(
//     title: 'Скидка 5% 🔥',
//     text: 'Для вас доступен промокод на первую покупку в Gravity',
//     circleIconBackground: Color(0xFFF0F0F0),
//     circeIconAssetImage: 'assets/images/heart.png',
//   );
//
//   if (context.mounted) {
//     final snackBar = GravitySnackBar.getSnackBar(type: snackBarType, data: snackBarData);
//     ScaffoldMessenger.of(context).showSnackBar(snackBar.toMaterialSnackBar());
//   }
// }
}
