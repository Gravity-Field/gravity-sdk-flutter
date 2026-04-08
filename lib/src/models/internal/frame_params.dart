import 'package:json_annotation/json_annotation.dart';

part 'frame_params.g.dart';

@JsonSerializable()
class FrameParams {
  final int? duration;

  const FrameParams({this.duration});

  factory FrameParams.fromJson(Map<String, dynamic> json) => _$FrameParamsFromJson(json);
}
