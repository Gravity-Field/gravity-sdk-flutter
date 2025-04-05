class Item {
  final String sku;
  final String groupId;
  final String name;
  final String price;
  final String url;
  final String imageUrl;
  final String isNew;
  final String oldPrice;
  final String bitrixId;
  final List<String> categories;
  final List<String> keywords;
  final String brand;
  final bool inStock;

  Item({
    required this.sku,
    required this.groupId,
    required this.name,
    required this.price,
    required this.url,
    required this.imageUrl,
    required this.isNew,
    required this.oldPrice,
    required this.bitrixId,
    required this.categories,
    required this.keywords,
    required this.brand,
    required this.inStock,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      sku: json['sku'],
      groupId: json['group_id'],
      name: json['name'],
      price: json['price'],
      url: json['url'],
      imageUrl: json['image_url'],
      isNew: json['is_new'],
      oldPrice: json['old_price'],
      bitrixId: json['bitrix_id'],
      categories: List<String>.from(json['categories']),
      keywords: List<String>.from(json['keywords']),
      brand: json['brand'],
      inStock: json['in_stock'],
    );
  }

}