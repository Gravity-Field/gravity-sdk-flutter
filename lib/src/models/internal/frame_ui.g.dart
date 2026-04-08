// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frame_ui.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FrameUI _$FrameUIFromJson(Map<String, dynamic> json) => FrameUI(
  container: FrameContainer.fromJson(json['container'] as Map<String, dynamic>),
  close: json['close'] == null
      ? null
      : Close.fromJson(json['close'] as Map<String, dynamic>),
  params: json['params'] == null
      ? null
      : FrameParams.fromJson(json['params'] as Map<String, dynamic>),
  arrow: json['arrow'] == null
      ? null
      : Arrow.fromJson(json['arrow'] as Map<String, dynamic>),
);
