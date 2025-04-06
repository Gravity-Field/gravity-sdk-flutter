import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/bottom_sheet/bottom_sheet_products_row.dart';

import 'data/content_response.dart';
import 'models/delivery_type.dart';
import 'repos/gravity_repo.dart';
import 'ui/delivery_methods/bottom_sheet/bottom_sheet_from_content.dart';
import 'ui/delivery_methods/full_screen/full_screen_from_content.dart';
import 'ui/delivery_methods/modal/modal_from_content.dart';

class GravitySDK {
  GlobalKey<NavigatorState>? navigatorKey;
  final _repo = GravityRepo();

  GravitySDK._();

  static final GravitySDK instance = GravitySDK._();

  void initialize({GlobalKey<NavigatorState>? navigatorKey}) {
    this.navigatorKey = navigatorKey;
  }

  Future<void> onAddToCartEvent(BuildContext context) async {
    await _repo.sendEvent();

    final response = await _repo.getContent('modal-template-1-elements');

    final content = response.data.first.payload.first.contents.first;

    switch (content.deliveryMethod) {
      case DeliveryMethod.modal:
        if (context.mounted) {
          showModalContent(context, response);
        }
        break;
      default:
    }
  }

  Future<ContentResponse> getContent(String template) {
    return _repo.getContent(template);
  }

  void showModalContent(BuildContext context, ContentResponse contentResponse) {
    final content = contentResponse.data.first.payload.first.contents.first;

    if (context.mounted) {
      final modal = ModalFromContent(content: content);

      showDialog(
        context: context,
        builder: (context) {
          return modal;
        },
      );
    }
  }

  void showBottomSheetContent(BuildContext context, ContentResponse contentResponse) {
    final content = contentResponse.data.first.payload.first.contents.first;

    if (context.mounted) {
      final bottomSheet = BottomSheetFromContent(content: content);

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
    final content = contentResponse.data.first.payload.first.contents.first;

    if (context.mounted) {
      final fullScreen = FullScreenFromContent(content: content);
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
    final content = contentResponse.data.first.payload.first.contents.first;

    if (context.mounted) {
      final bottomSheet = BottomSheetProductsRow(content: content);

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
