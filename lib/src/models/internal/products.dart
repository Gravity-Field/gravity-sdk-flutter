import 'slot.dart';

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

  factory Products.fromJson(Map<String, dynamic> json) {
    return Products(
      strategyId: json['strategyId'],
      name: json['name'],
      pageNumber: json['pageNumber'],
      countPages: json['countPages'],
      fallback: json['fallback'],
      slots: (json['slots'] as List).map((e) => Slot.fromJson(e)).toList(),
    );
  }

}