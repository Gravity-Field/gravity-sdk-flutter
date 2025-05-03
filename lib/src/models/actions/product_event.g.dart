// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductEvent _$ProductEventFromJson(Map<String, dynamic> json) => ProductEvent(
      name: $enumDecode(_$ProductActionEnumMap, json['name']),
      urls: (json['urls'] as List<dynamic>).map((e) => e as String).toList(),
    );

const _$ProductActionEnumMap = {
  ProductAction.pimp: 'PIMP',
  ProductAction.pclick: 'PCLICK',
  ProductAction.unknown: 'unknown',
};
