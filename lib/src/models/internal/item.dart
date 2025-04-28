import 'package:json_annotation/json_annotation.dart';

part 'item.g.dart';

@JsonSerializable()
class Item {
  final String sku;
  final String? groupId;
  final String name;
  final String price;
  final String url;
  final String? imageUrl;
  final String? isNew;
  final String? oldPrice;
  final String? bitrixId;
  final List<String> categories;
  final List<String> keywords;
  final String? brand;
  final bool? inStock;

  Item({
    required this.sku,
    this.groupId,
    required this.name,
    required this.price,
    required this.url,
    this.imageUrl,
    this.isNew,
    this.oldPrice,
    this.bitrixId,
    required this.categories,
    required this.keywords,
    this.brand,
    this.inStock,
  });

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}