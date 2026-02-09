import 'package:json_annotation/json_annotation.dart';

import '../../data/error_reporting/error_reporter.dart';
import 'action.dart';

part 'on_click.g.dart';

@JsonSerializable()
class OnClick {
  @JsonKey(unknownEnumValue: Action.unknown)
  final Action action;
  final String? copyData;
  final int? step;
  final String? url;
  final String? deeplink;
  final bool closeOnClick;

  OnClick({
    required this.action,
    this.copyData,
    this.step,
    this.url,
    this.deeplink,
    this.closeOnClick = true,
  });

  factory OnClick.fromJson(Map<String, dynamic> json) {
    final result = _$OnClickFromJson(json);
    if (result.action == Action.unknown) {
      ErrorReporter.instance.report(
        message: 'Unknown onClick action: ${json['action']}',
        level: 'warning',
        section: 'OnClick.fromJson',
        tags: {'category': 'parsing'},
      );
    }
    return result;
  }
}
