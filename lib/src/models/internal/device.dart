import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@JsonSerializable(createToJson: true, createFactory: false, includeIfNull: false)
class Device {
  final String userAgent;
  final String? id;
  final String? tracking;
  final String? permission;

  const Device({
    required this.userAgent,
    required this.id,
    this.tracking,
    this.permission,
  });

  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}
