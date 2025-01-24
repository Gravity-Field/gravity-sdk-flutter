import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/widgets/snackbar/snackbar_type_1.dart';

enum GravitySnackBarType {
  type1,
}

abstract class GravitySnackBar {

  GravitySnackBar();

  SnackBar toMaterialSnackBar();

  factory GravitySnackBar.getSnackBar(GravitySnackBarType type) {
    return switch (type) {
      GravitySnackBarType.type1 => SnackBarType1(
          title: 'Скидка 5%',
          text: 'Для вас доступен промокод на первую покупку в Mindbox',
          imageUrl: 'https://cdn-icons-png.flaticon.com/512/3012/3012388.png',
        ),
    };
  }

}
