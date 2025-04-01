import 'package:gravity_sdk/src/models/style.dart';

class Container {
  final Style style;

  Container({required this.style});

  factory Container.fromJson(Map<String, dynamic> json) {
    return Container(
      style: Style.fromJson(json['style']),
    );
  }
}