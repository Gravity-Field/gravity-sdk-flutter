import 'package:json_annotation/json_annotation.dart';

import '../../data/error_reporting/error_reporter.dart';
import 'action.dart';
import 'follow_url_type.dart';
import 'form_action.dart';

export 'follow_url_type.dart';

part 'on_click.g.dart';

@JsonSerializable()
class OnClick {
  @JsonKey(unknownEnumValue: Action.unknown)
  final Action action;
  final String? copyData;
  final int? step;
  final String? url;
  final String? deeplink;
  @JsonKey(
    defaultValue: FollowUrlType.browser,
    unknownEnumValue: FollowUrlType.browser,
  )
  final FollowUrlType type;
  final bool closeOnClick;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final FormEventSpec? event;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<FormRoute>? routes;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final FormRoute? defaultRoute;

  OnClick({
    required this.action,
    this.copyData,
    this.step,
    this.url,
    this.deeplink,
    this.type = FollowUrlType.browser,
    this.closeOnClick = true,
    this.event,
    this.routes,
    this.defaultRoute,
  });

  factory OnClick.fromJson(Map<String, dynamic> json) {
    if (json['action'] == 'submit_form') {
      try {
        final result = _$OnClickFromJson(json);
        final event = FormEventSpec.tryParse(json['event']);
        final defaultRoute = FormRoute.tryParse(
          json['default'],
          requireWhen: false,
        );
        if (event == null || defaultRoute == null) {
          throw const FormatException('Invalid submit_form payload');
        }

        final rawRoutes = json.containsKey('routes')
            ? json['routes']
            : const <Object?>[];
        if (rawRoutes is! List) {
          throw const FormatException('Invalid submit_form routes');
        }
        final routes = <FormRoute>[];
        for (final rawRoute in rawRoutes) {
          final route = FormRoute.tryParse(rawRoute, requireWhen: true);
          if (route == null) {
            throw const FormatException('Invalid submit_form route');
          }
          routes.add(route);
        }

        return OnClick(
          action: result.action,
          copyData: result.copyData,
          step: result.step,
          url: result.url,
          deeplink: result.deeplink,
          type: result.type,
          closeOnClick: result.closeOnClick,
          event: event,
          routes: routes,
          defaultRoute: defaultRoute,
        );
      } catch (error) {
        ErrorReporter.instance.report(
          message: 'Invalid submit_form onClick: $error',
          level: 'warning',
          section: 'OnClick.fromJson',
          tags: {'category': 'parsing'},
        );
        return OnClick(action: Action.unknown, closeOnClick: false);
      }
    }

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
