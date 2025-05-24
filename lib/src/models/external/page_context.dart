import 'package:json_annotation/json_annotation.dart';

part 'page_context.g.dart';

@JsonEnum()
enum ContextType {
  homepage,
  product,
  cart,
  category,
  search,
  other;
}

@JsonSerializable(createToJson: true, createFactory: false)
class PageContext {
  final ContextType type;

  PageContext(this.type);

  Map<String, dynamic> toJson() => _$PageContextToJson(this);
}
