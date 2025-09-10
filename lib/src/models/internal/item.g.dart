// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) => Item(
      sku: json['sku'] as String,
      groupId: json['groupId'] as String?,
      name: json['name'] as String?,
      price: json['price'] as String?,
      url: json['url'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isNew: json['isNew'] as String?,
      oldPrice: json['oldPrice'] as String?,
      bitrixId: json['bitrixId'] as String?,
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      keywords: (json['keywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      brand: json['brand'] as String?,
      inStock: json['inStock'] as bool?,
    );
