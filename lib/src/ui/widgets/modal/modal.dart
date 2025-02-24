import 'package:flutter/material.dart';

import 'modal_data.dart';
import 'modal_type.dart';
import 'modal_type_1.dart';


class GravityModal extends StatelessWidget {
  final ModalType type;
  final ModalData data;

  const GravityModal({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
        ModalType.type1 => ModalType1(data: data),
    };
  }
}
