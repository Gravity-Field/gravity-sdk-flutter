import 'package:flutter/material.dart' hide Action;
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/actions/product_action.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_products_row.dart';
import 'package:gravity_sdk/src/utils/content_events_service.dart';
import 'package:gravity_sdk/src/utils/device_utils.dart';

import 'data/api/content_response.dart';
import 'models/external/user.dart';
import 'models/internal/device.dart';
import 'repos/gravity_repo.dart';
import 'ui/delivery_methods/bottom_sheet/bottom_sheet_from_content.dart';
import 'ui/delivery_methods/full_screen/full_screen_from_content.dart';
import 'ui/delivery_methods/modal/modal_from_content.dart';

class GravitySDK {
  //init fields
  String apiKey = '';
  String section = '';
  ProductWidgetBuilder productWidgetBuilder = DefaultProductWidgetBuilder();
  void Function(OnClick onClick)? globalOnClickCallback;

  //other fields
  User? user;
  late Device device;
  ContentSettings contentSettings = ContentSettings();
  Options options = Options();

  GravitySDK._();

  static final GravitySDK instance = GravitySDK._();

  final _gravityRepo = GravityRepo.instance;

  Future<void> initialize({
    required String apiKey,
    required String section,
    ProductWidgetBuilder? productWidgetBuilder,
    void Function(OnClick onClick)? globalOnClickCallback,
    bool useAdvertisingId = false,
  }) async {
    this.apiKey = apiKey;
    this.section = section;
    this.productWidgetBuilder = productWidgetBuilder ?? DefaultProductWidgetBuilder();
    this.globalOnClickCallback = globalOnClickCallback;

    final userAgent = await DeviceUtils.getUserAgent();
    final deviceIdentifier = await DeviceUtils.getDeviceId(useAdvertisingId);

    device = Device(
      userAgent: userAgent,
      id: deviceIdentifier,
    );
  }

  void setOptions({Options? options, ContentSettings? contentSettings}) {
    if (options != null) {
      this.options = options;
    }
    if (contentSettings != null) {
      this.contentSettings = contentSettings;
    }
  }

  void setUser(String userId, String sessionId) {
    user = User(
      custom: userId,
      ses: sessionId,
    );
  }

  Future<void> trackView({required PageContext pageContext}) async {
    _checkIsInitialized();
    await _gravityRepo.visit(customUser: user, pageContext: pageContext, options: options);
  }

  Future<void> triggerEvent({required String event, required PageContext pageContext}) async {
    _checkIsInitialized();
    await _gravityRepo.event(event: event, customUser: user, pageContext: pageContext, options: options);
  }

  void sendEngagement(ProductAction action, Slot slot) {}

  Future<ContentResponse> getContent(String template) async {
    _checkIsInitialized();

    final content =
        await _gravityRepo.getContent(templateId: template, options: options, contentSetting: contentSettings);

    for (final data in content.data) {
      for (final payload in data.payload) {
        for (final content in payload.contents) {
          ContentEventsService.instance.sendContentLoaded(content);
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
