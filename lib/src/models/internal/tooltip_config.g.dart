// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tooltip_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TooltipConfig _$TooltipConfigFromJson(Map<String, dynamic> json) =>
    TooltipConfig(
      position: $enumDecodeNullable(_$TooltipPositionEnumMap, json['position']),
      arrowPosition: $enumDecodeNullable(
        _$ArrowPositionEnumMap,
        json['arrowPosition'],
      ),
      distanceFromAnchor: ParseUtils.parseDimension(json['distanceFromAnchor']),
      arrowSize: ParseUtils.parseDimension(json['arrowSize']),
      dismissOnTapOutside: json['dismissOnTapOutside'] as bool?,
      autoDismissSeconds: ParseUtils.parseDimension(json['autoDismissSeconds']),
      showBackdrop: json['showBackdrop'] as bool?,
      backdropColor: ParseUtils.parseColor(json['backdropColor']),
      maxWidth: ParseUtils.parseDimension(json['maxWidth']),
    );

const _$TooltipPositionEnumMap = {
  TooltipPosition.top: 'top',
  TooltipPosition.bottom: 'bottom',
  TooltipPosition.left: 'left',
  TooltipPosition.right: 'right',
  TooltipPosition.auto: 'auto',
};

const _$ArrowPositionEnumMap = {
  ArrowPosition.start: 'start',
  ArrowPosition.center: 'center',
  ArrowPosition.end: 'end',
};
