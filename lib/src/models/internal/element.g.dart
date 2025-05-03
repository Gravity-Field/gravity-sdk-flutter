// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'element.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Element _$ElementFromJson(Map<String, dynamic> json) => Element(
      type: $enumDecode(_$ElementTypeEnumMap, json['type']),
      text: json['text'] as String?,
      src: json['src'] as String?,
      style: json['style'] == null
          ? null
          : Style.fromJson(json['style'] as Map<String, dynamic>),
      onClick: json['onClick'] == null
          ? null
          : OnClick.fromJson(json['onClick'] as Map<String, dynamic>),
    );

const _$ElementTypeEnumMap = {
  ElementType.image: 'image',
  ElementType.text: 'text',
  ElementType.button: 'button',
  ElementType.spacer: 'spacer',
  ElementType.productsContainer: 'products-container',
  ElementType.unknown: 'unknown',
};
