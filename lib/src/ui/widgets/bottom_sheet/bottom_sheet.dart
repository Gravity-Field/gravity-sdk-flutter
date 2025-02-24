import 'package:flutter/material.dart';
import 'bottom_sheet_data.dart';
import 'bottom_sheet_type.dart';
import 'bottom_sheet_type_1.dart';

class GravityBottomSheet extends StatelessWidget {
  final BottomSheetType type;
  final BottomSheetData data;

  const GravityBottomSheet({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      BottomSheetType.type1 => BottomSheetType1(data: data),
    };
  }
}
