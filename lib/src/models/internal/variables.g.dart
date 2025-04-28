// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variables.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Variables _$VariablesFromJson(Map<String, dynamic> json) => Variables(
      frameUI: json['frameUI'] == null
          ? null
          : FrameUI.fromJson(json['frameUI'] as Map<String, dynamic>),
      elements: (json['elements'] as List<dynamic>)
          .map((e) => Element.fromJson(e as Map<String, dynamic>))
          .toList(),
      onLoad: json['onLoad'] == null
          ? null
          : Action.fromJson(json['onLoad'] as Map<String, dynamic>),
      onImpression: json['onImpression'] == null
          ? null
          : Action.fromJson(json['onImpression'] as Map<String, dynamic>),
      onVisibleImpression: json['onVisibleImpression'] == null
          ? null
          : Action.fromJson(
              json['onVisibleImpression'] as Map<String, dynamic>),
      onClose: json['onClose'] == null
          ? null
          : Action.fromJson(json['onClose'] as Map<String, dynamic>),
    );
