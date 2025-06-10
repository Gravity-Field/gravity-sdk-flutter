import 'package:json_annotation/json_annotation.dart';

part 'page_context.g.dart';

@JsonEnum()
enum ContextType {
  @JsonValue('HOMEPAGE')
  homepage,
  @JsonValue('PRODUCT')
  product,
  @JsonValue('CART')
  cart,
  @JsonValue('CATEGORY')
  category,
  @JsonValue('SEARCH')
  search,
  @JsonValue('OTHER')
  other;
}

@JsonSerializable(createToJson: true, createFactory: false)
class PageContext {
  final ContextType type;
  final List<String> data;
  final String location;
  final String? lng;
  final Map<String, String>? utm;
  final Map<String, Object>? attributes;

  const PageContext({
    required this.type,
    required this.data,
    required this.location,
    this.lng,
    this.utm,
    this.attributes,
  });

  Map<String, dynamic> toJson() => _$PageContextToJson(this);


}
