import 'package:json_annotation/json_annotation.dart';

part 'options.g.dart';

@JsonSerializable(createToJson: true)
class Options {
  final bool isReturnCounter;
  final bool isReturnUserInfo;
  final bool isReturnAnalyticsMetadata;
  final bool isImplicitPageview;
  final bool isImplicitImpression;
  @JsonKey(includeToJson: true, includeFromJson: true)
  final bool isBuildEngagementUrl = true;

  const Options({
    this.isReturnCounter = false,
    this.isReturnUserInfo = false,
    this.isReturnAnalyticsMetadata = false,
    this.isImplicitPageview = false,
    this.isImplicitImpression = true,
  });

  Map<String, dynamic> toJson() => _$OptionsToJson(this);

  factory Options.fromJson(Map<String, dynamic> json) => _$OptionsFromJson(json);
}
