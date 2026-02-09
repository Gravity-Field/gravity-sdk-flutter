import 'package:json_annotation/json_annotation.dart';

import '../../data/error_reporting/error_reporter.dart';
import 'action.dart';

part 'content_action.g.dart';

@JsonSerializable()
class ContentAction {
  @JsonKey(unknownEnumValue: Action.unknown)
  final Action action;

  const ContentAction({
    required this.action,
  });

  factory ContentAction.fromJson(Map<String, dynamic> json) {
    final result = _$ContentActionFromJson(json);
    if (result.action == Action.unknown) {
      ErrorReporter.instance.report(
        message: 'Unknown content action: ${json['action']}',
        level: 'warning',
        section: 'ContentAction.fromJson',
        tags: {'category': 'parsing'},
      );
    }
    return result;
  }
}

