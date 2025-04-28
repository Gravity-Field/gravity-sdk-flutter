import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(createToJson: true)
class User {
  final String? uid;
  final String? custom;
  final String? ses;
  final Map<String, dynamic>? attributes;

  const User({
    this.uid,
    this.custom,
    this.ses,
    this.attributes,
  });

  Map<String, dynamic> toJson() => _$UserToJson(this);

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
