import 'package:json_annotation/json_annotation.dart';

import 'slot.dart';

part 'products.g.dart';

@JsonSerializable()
class Products {
  final String strategyId;
  final String name;
  final int pageNumber;
  final int countPages;
  final bool fallback;
  final List<Slot> slots;

  Products({
    required this.strategyId,
    required this.name,
    required this.pageNumber,
    required this.countPages,
    required this.fallback,
    required this.slots,
  });

  factory Products.fromJson(Map<String, dynamic> json) => _$ProductsFromJson(json);
}