import 'package:json_annotation/json_annotation.dart';

import '../../data/error_reporting/error_reporter.dart';
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
  @JsonValue('webview')
  webview,
  unknown,
}

@JsonSerializable()
class Element {
  @JsonKey(unknownEnumValue: ElementType.unknown)
  final ElementType type;
  final String? text;
  final String? src;
  final Style? style;
  final OnClick? onClick;

  Element({required this.type, this.text, this.src, required this.style, this.onClick});

  factory Element.fromJson(Map<String, dynamic> json) {
    final result = _$ElementFromJson(json);
    if (result.type == ElementType.unknown) {
      ErrorReporter.instance.report(
        message: 'Unknown element type: ${json['type']}',
        level: 'warning',
        section: 'Element.fromJson',
        tags: {'category': 'parsing'},
      );
    }
    return result;
  }
}
