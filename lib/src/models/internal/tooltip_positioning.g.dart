// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tooltip_positioning.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TooltipPositioning _$TooltipPositioningFromJson(
  Map<String, dynamic> json,
) => TooltipPositioning(
  direction: $enumDecodeNullable(_$TooltipDirectionEnumMap, json['direction']),
  alignment: $enumDecodeNullable(_$TooltipAlignmentEnumMap, json['alignment']),
  offset: ParseUtils.parseDimension(json['offset']),
  allowFlip: json['allowFlip'] as bool?,
);

const _$TooltipDirectionEnumMap = {
  TooltipDirection.top: 'top',
  TooltipDirection.bottom: 'bottom',
  TooltipDirection.left: 'left',
  TooltipDirection.right: 'right',
};

const _$TooltipAlignmentEnumMap = {
  TooltipAlignment.start: 'start',
  TooltipAlignment.center: 'center',
  TooltipAlignment.end: 'end',
};
