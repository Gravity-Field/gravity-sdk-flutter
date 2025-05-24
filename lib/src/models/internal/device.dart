import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@JsonSerializable(createToJson: true, createFactory: false)
class Device {
  final Map<String, dynamic> userAgent;
  final String? id;

  const Device({
    required this.userAgent,
    required this.id,
  });

  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}