import 'package:flutter/material.dart';

class ModalData {
  final String? networkIcon;
  final String? assetsIcon;
  final String title;
  final String description;
  final CrossAxisAlignment crossAxisAlignment;

  const ModalData({
    this.networkIcon,
    this.assetsIcon,
    required this.title,
    required this.description,
    required this.crossAxisAlignment,
  });
}
