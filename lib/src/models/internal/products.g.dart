// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Products _$ProductsFromJson(Map<String, dynamic> json) => Products(
      strategyId: json['strategyId'] as String,
      name: json['name'] as String,
      pageNumber: (json['pageNumber'] as num?)?.toInt(),
      countPages: (json['countPages'] as num?)?.toInt(),
      fallback: json['fallback'] as bool,
      slots: (json['slots'] as List<dynamic>?)
          ?.map((e) => Slot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
