enum ContextType {
  homepage,
  product,
  cart,
  category,
  search,
  other;
}

class PageContext {
  final ContextType type;

  PageContext(this.type);

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
      };
}
