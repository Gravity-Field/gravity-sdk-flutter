import 'package:json_annotation/json_annotation.dart';

import '../actions/on_click.dart';
import 'style.dart';

part 'element.g.dart';

@JsonEnum()
enum ElementType {
  @JsonValue('image')
  image,
  @JsonValue('text')
  text,
  @JsonValue('button')
  button,
  @JsonValue('spacer')
  spacer,
  @JsonValue('products-container')
  productsContainer,
  unknown;
}

@JsonSerializable()
class Element {
  final ElementType type;
  final String? text;
  final String? src;
  final Style? style;
  final OnClick? onClick;

  Element({
    required this.type,
    this.text,
    this.src,
    required this.style,
    this.onClick,
  });

  factory Element.fromJson(Map<String, dynamic> json) => _$ElementFromJson(json);
}
