import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ProductContainerType {
  @JsonValue('row')
  row,
  @JsonValue('grid')
  grid;
}
