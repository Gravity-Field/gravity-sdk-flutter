import 'package:gravity_sdk/src/models/style.dart';

import 'action.dart';

class Close {
  final String? image;
  final Action? onClick;
  final Style style;

  Close({this.image, this.onClick, required this.style});

  factory Close.fromJson(Map<String, dynamic> json) {
    return Close(
      image: json['image'],
      onClick: json['onClick'] != null ? Action.fromJson(json['onClick']) : null,
      style: Style.fromJson(json['style']),
    );
  }
}
