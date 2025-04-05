import 'style.dart';

enum GravityElementType {
  image,
  text,
  button,
  spacer,
  unknown;

  static GravityElementType fromString(String type) {
    switch (type) {
      case 'image':
        return GravityElementType.image;
      case 'text':
        return GravityElementType.text;
      case 'button':
        return GravityElementType.button;
      case 'spacer':
        return GravityElementType.spacer;
      default:
        return GravityElementType.unknown;
    }
  }
}

class GravityElement {
  final GravityElementType type;
  final String? text;
  final String? src;
  final Style? style;

  GravityElement({required this.type, this.text, this.src, required this.style});

  factory GravityElement.fromJson(Map<String, dynamic> json) {
    return GravityElement(
      type: GravityElementType.fromString(json['type']),
      text: json['text'],
      src: json['src'],
      style: json['style'] != null ? Style.fromJson(json['style']) : null,
      // style: Style.fromJson(json['style']),
    );
  }
}
