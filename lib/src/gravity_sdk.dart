import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/delivery_type.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';
import 'package:gravity_sdk/src/ui/widgets/bottom_sheet/bottom_sheet.dart';
import 'package:gravity_sdk/src/ui/widgets/bottom_sheet/bottom_sheet_data.dart';
import 'package:gravity_sdk/src/ui/widgets/bottom_sheet/bottom_sheet_type.dart';
import 'package:gravity_sdk/src/ui/widgets/snackbar/snackbar.dart';
import 'package:gravity_sdk/src/ui/widgets/snackbar/snackbar_data.dart';

import 'ui/widgets/modal/modal.dart';
import 'ui/widgets/modal/modal_data.dart';
import 'ui/widgets/modal/modal_type.dart';
import 'ui/widgets/snackbar/snackbar_type.dart';

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
    final deliveryType = await _repo.getContent();

    print('Delivery type = $deliveryType');

    switch (deliveryType) {
      case DeliveryType.snackBar:
        if (context.mounted) {
          _showSnackBar(context);
        }
      case DeliveryType.modal:
        if (context.mounted) {
          _showModal(context);
        }
      case DeliveryType.bottomSheet:
        if (context.mounted) {
          _showBottomSheet(context);
        }
      case DeliveryType.fullScreen:
      case DeliveryType.inline:
    }
  }

  void _showSnackBar(BuildContext context) {
    final snackBarType = SnackBarType.type1;
    final snackBarData = SnackBarData(
      title: 'Скидка 5% 🔥',
      text: 'Для вас доступен промокод на первую покупку в Gravity',
      circleIconBackground: Color(0xFFF0F0F0),
      circeIconAssetImage: 'assets/images/heart.png',
    );

    if (context.mounted) {
      final snackBar = GravitySnackBar.getSnackBar(type: snackBarType, data: snackBarData);
      ScaffoldMessenger.of(context).showSnackBar(snackBar.toMaterialSnackBar());
    }
  }

  void _showModal(BuildContext context) {
    final modalType = ModalType.type1;
    final modalData = ModalData(
      assetsIcon: 'assets/icons/circle_check.svg',
      title: 'Скидка 5% 🔥',
      description: 'Поздравляем! Для вас доступен промокод на первую покупку в Gravity Ads',
      crossAxisAlignment: CrossAxisAlignment.start,
    );

    if (context.mounted) {
      final modal = GravityModal(
        type: modalType,
        data: modalData,
      );

      showDialog(
        context: context,
        builder: (context) {
          return modal;
        },
      );
    }
  }

  void _showBottomSheet(BuildContext context) {
    final bottomSheetType = BottomSheetType.type1;
    final bottomSheetData = BottomSheetData(
      title: 'Осталось 3 дня!',
      text: 'Ваш промокод вот-вот сгорит — воспользуетесь?',
      circleIconBackground: Color(0xFFF0F0F0),
      circeIconAssetImage: 'assets/images/heart.png',
      buttonText: 'За покупками!',
      backgroundColor: Colors.white,
    );

    if (context.mounted) {
      final bottomSheet = GravityBottomSheet(
        type: bottomSheetType,
        data: bottomSheetData,
      );

      showModalBottomSheet(
        context: context,
        backgroundColor: bottomSheetData.backgroundColor,
        builder: (context) {
          return bottomSheet;
        },
      );
    }
  }
}
