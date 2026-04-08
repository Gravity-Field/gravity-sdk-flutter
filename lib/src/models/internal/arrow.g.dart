// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arrow.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Arrow _$ArrowFromJson(Map<String, dynamic> json) => Arrow(
  width: ParseUtils.parseDimension(json['width']),
  height: ParseUtils.parseDimension(json['height']),
  color: ParseUtils.parseColor(json['color']),
  alignment: $enumDecodeNullable(_$ArrowAlignmentEnumMap, json['alignment']),
);

const _$ArrowAlignmentEnumMap = {
  ArrowAlignment.start: 'start',
  ArrowAlignment.center: 'center',
  ArrowAlignment.end: 'end',
};
