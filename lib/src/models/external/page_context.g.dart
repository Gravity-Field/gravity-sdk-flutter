// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PageContextToJson(PageContext instance) =>
    <String, dynamic>{
      'type': _$ContextTypeEnumMap[instance.type]!,
      'data': instance.data,
      'location': instance.location,
      'lng': instance.lng,
      'utm': instance.utm,
      'attributes': instance.attributes,
    };

const _$ContextTypeEnumMap = {
  ContextType.homepage: 'HOMEPAGE',
  ContextType.product: 'PRODUCT',
  ContextType.cart: 'CART',
  ContextType.category: 'CATEGORY',
  ContextType.search: 'SEARCH',
  ContextType.other: 'OTHER',
};
