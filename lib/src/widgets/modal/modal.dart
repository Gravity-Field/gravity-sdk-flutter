import 'package:flutter/material.dart';

import 'modal_data.dart';
import 'modal_type_1.dart';
import 'modal_type_2.dart';
import 'modal_type_3.dart';

enum GravityModalType {
  type1,
  // type2,
  // type3,
}

class GravityModal extends StatelessWidget {
  final GravityModalType type;
  final ModalData data;

  const GravityModal({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      GravityModalType.type1 => ModalType1(data: data),
      // GravityModalType.type2 => ModalType2(imageUrl: 'https://cdn-icons-png.flaticon.com/512/3012/3012388.png'),
      // GravityModalType.type3 => ModalType3(),
    };
  }
}
