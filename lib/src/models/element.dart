import 'style.dart';
import 'action.dart';

enum ElementType {
  image,
  text,
  button,
  spacer,
  productsContainer,
  unknown;

  static ElementType fromString(String type) {
    switch (type) {
      case 'image':
        return ElementType.image;
      case 'text':
        return ElementType.text;
      case 'button':
        return ElementType.button;
      case 'spacer':
        return ElementType.spacer;
      case 'products-container':
        return ElementType.productsContainer;
      default:
        return ElementType.unknown;
    }
  }
}

class Element {
  final ElementType type;
  final String? text;
  final String? src;
  final Style? style;
  final Action? onClick;

  Element({
    required this.type,
    this.text,
    this.src,
    required this.style,
    this.onClick,
  });

  factory Element.fromJson(Map<String, dynamic> json) {
    return Element(
      type: ElementType.fromString(json['type']),
      text: json['text'],
      src: json['src'],
      style: json['style'] != null ? Style.fromJson(json['style']) : null,
      onClick: json['onClick'] != null ? Action.fromJson(json['onClick']) : null,
    );
  }
}
