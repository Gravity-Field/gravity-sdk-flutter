import 'package:flutter/material.dart';

import 'snackbar_data.dart';
import 'snackbar_type.dart';
import 'snackbar_type_1.dart';

abstract class GravitySnackBar {
  GravitySnackBar();

  SnackBar toMaterialSnackBar();

  factory GravitySnackBar.getSnackBar({
    required SnackBarType type,
    required SnackBarData data,
  }) {
    return switch (type) {
      SnackBarType.type1 => SnackBarType1(data: data),
    };
  }
}
