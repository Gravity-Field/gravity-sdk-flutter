import 'package:flutter/material.dart';

import 'modal_type_1.dart';
import 'modal_type_2.dart';
import 'modal_type_3.dart';

enum GravityModalType {
  type1,
  type2,
  type3,
}

class GravityModal extends StatelessWidget {
  final GravityModalType type;

  const GravityModal({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      GravityModalType.type1 => ModalType1(
          imageSize: 80,
          buttonSize: 60,
          imageUrl: 'https://cdn-icons-png.flaticon.com/512/3012/3012388.png',
        ),
      GravityModalType.type2 => ModalType2(),
      GravityModalType.type3 => ModalType3(),
    };
  }
}
