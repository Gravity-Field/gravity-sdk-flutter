import 'package:flutter/material.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/widgets/full_screen/gravity_full_screen.dart';
import 'package:gravity_sdk/src/widgets/snackbar/snackbar.dart';

import 'widgets/modal/modal.dart';

class GravitySDK {
  GravityModal getModal({required GravityModalType type}) {
    return GravityModal(type: type);
  }

  SnackBar getSnackBar({required GravitySnackBarType type}) {
    return GravitySnackBar.getSnackBar(type).toMaterialSnackBar();
  }

  GravityBottomSheet getBottomSheet() {
    return const GravityBottomSheet();
  }

  GravityFullScreen getFullScreen() {
    return const GravityFullScreen();
  }
}
