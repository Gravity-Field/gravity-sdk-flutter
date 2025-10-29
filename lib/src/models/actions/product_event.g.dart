// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductEvent _$ProductEventFromJson(Map<String, dynamic> json) => ProductEvent(
  type: $enumDecode(
    _$ProductActionEnumMap,
    json['type'],
    unknownValue: ProductAction.unknown,
  ),
  urls: (json['urls'] as List<dynamic>).map((e) => e as String).toList(),
);

const _$ProductActionEnumMap = {
  ProductAction.impression: 'impression',
  ProductAction.visibleImpression: 'visible_impression',
  ProductAction.click: 'click',
  ProductAction.unknown: 'unknown',
};
