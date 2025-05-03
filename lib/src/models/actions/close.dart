import 'package:json_annotation/json_annotation.dart';

import '../internal/style.dart';
import 'on_click.dart';

part 'close.g.dart';

@JsonSerializable()
class Close {
  final String? image;
  final OnClick? onClick;
  final Style style;

  Close({this.image, this.onClick, required this.style});

  factory Close.fromJson(Map<String, dynamic> json) => _$CloseFromJson(json);
}
