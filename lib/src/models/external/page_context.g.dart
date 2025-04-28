// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageContext _$PageContextFromJson(Map<String, dynamic> json) => PageContext(
      $enumDecode(_$ContextTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$PageContextToJson(PageContext instance) =>
    <String, dynamic>{
      'type': _$ContextTypeEnumMap[instance.type]!,
    };

const _$ContextTypeEnumMap = {
  ContextType.homepage: 'homepage',
  ContextType.product: 'product',
  ContextType.cart: 'cart',
  ContextType.category: 'category',
  ContextType.search: 'search',
  ContextType.other: 'other',
};
