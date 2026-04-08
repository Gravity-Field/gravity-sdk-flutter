// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variables.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Variables _$VariablesFromJson(Map<String, dynamic> json) => Variables(
  frameUI: json['frameUI'] == null
      ? null
      : FrameUI.fromJson(json['frameUI'] as Map<String, dynamic>),
  elements: (json['elements'] as List<dynamic>?)
      ?.map((e) => Element.fromJson(e as Map<String, dynamic>))
      .toList(),
  title: json['title'] as String?,
  onLoad: json['onLoad'] == null
      ? null
      : ContentAction.fromJson(json['onLoad'] as Map<String, dynamic>),
  onImpression: json['onImpression'] == null
      ? null
      : ContentAction.fromJson(json['onImpression'] as Map<String, dynamic>),
  onVisibleImpression: json['onVisibleImpression'] == null
      ? null
      : ContentAction.fromJson(
          json['onVisibleImpression'] as Map<String, dynamic>,
        ),
  onClose: json['onClose'] == null
      ? null
      : ContentAction.fromJson(json['onClose'] as Map<String, dynamic>),
  index: (json['index'] as num?)?.toInt() ?? 0,
  tooltipConfig: json['tooltipConfig'] == null
      ? null
      : TooltipConfig.fromJson(json['tooltipConfig'] as Map<String, dynamic>),
  positioning: json['positioning'] == null
      ? null
      : TooltipPositioning.fromJson(
          json['positioning'] as Map<String, dynamic>,
        ),
);
