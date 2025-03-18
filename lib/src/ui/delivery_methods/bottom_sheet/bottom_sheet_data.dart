import 'package:flutter/material.dart';

class BottomSheetData {
  final String title;
  final String text;
  final Color circleIconBackground;
  final String circeIconAssetImage;
  final String buttonText;
  final Color backgroundColor;

  const BottomSheetData({
    required this.title,
    required this.text,
    required this.circleIconBackground,
    required this.circeIconAssetImage,
    required this.buttonText,
    required this.backgroundColor,
  });
}
