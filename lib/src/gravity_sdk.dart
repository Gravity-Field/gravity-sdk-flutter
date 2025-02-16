import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/widgets/full_screen/gravity_full_screen.dart';
import 'package:gravity_sdk/src/widgets/modal/modal_data.dart';
import 'package:gravity_sdk/src/widgets/snackbar/snackbar.dart';

import 'widgets/modal/modal.dart';

class GravitySDK {
  GlobalKey<NavigatorState>? navigatorKey;
  final dio = Dio();

  GravitySDK._() {
    dio.options.baseUrl = 'https://api.gravitysdk.org';
  }

  static final GravitySDK instance = GravitySDK._();

  void initialize({GlobalKey<NavigatorState>? navigatorKey}) {
    this.navigatorKey = navigatorKey;
  }

  // GravityModal getModal({required GravityModalType type}) {
  //   return GravityModal(type: type);
  // }
  //
  // SnackBar getSnackBar({required GravitySnackBarType type}) {
  //   return GravitySnackBar.getSnackBar(type).toMaterialSnackBar();
  // }
  //
  // GravityBottomSheet getBottomSheet() {
  //   return const GravityBottomSheet();
  // }
  //
  // GravityFullScreen getFullScreen() {
  //   return const GravityFullScreen();
  // }

  Future<void> onAddToCartEvent(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 1));
    final modalType = GravityModalType.type1;
    final modalData = ModalData(
      assetsIcon: 'assets/icons/circle_check.svg',
      title: 'Скидка 5% 🔥',
      description: 'Поздравляем! Для вас доступен промокод на первую покупку в Gravity Ads',
      crossAxisAlignment: CrossAxisAlignment.start,
    );

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          final modal = GravityModal(
            type: modalType,
            data: modalData,
          );
          return modal;
        },
      );
    }
  }
}
