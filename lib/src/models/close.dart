import 'package:gravity_sdk/src/models/style.dart';

class Close {
  final String? image;
  final Style style;

  Close({this.image, required this.style});

  factory Close.fromJson(Map<String, dynamic> json) {
    return Close(
      image: json['image'],
      style: Style.fromJson(json['style']),
    );
  }
}
