import '../internal/condition.dart';
import 'follow_url_type.dart';

enum FormEffectType { close, openUrl, openDeeplink, openStep }

class FormEffect {
  final FormEffectType effect;
  final String? url;
  final String? deeplink;
  final int? step;
  final FollowUrlType urlType;

  const FormEffect({
    required this.effect,
    this.url,
    this.deeplink,
    this.step,
    this.urlType = FollowUrlType.browser,
  });

  static FormEffect? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;

    switch (json['effect']) {
      case 'close':
        return const FormEffect(effect: FormEffectType.close);
      case 'open_url':
      case 'follow_url':
        final url = json['url'];
        if (url is! String || url.isEmpty) return null;
        return FormEffect(
          effect: FormEffectType.openUrl,
          url: url,
          urlType: json['type'] == 'webview' ? FollowUrlType.webview : FollowUrlType.browser,
        );
      case 'open_deeplink':
        final deeplink = json['deeplink'];
        if (deeplink is! String || deeplink.isEmpty) return null;
        return FormEffect(
          effect: FormEffectType.openDeeplink,
          deeplink: deeplink,
        );
      case 'open_step':
        final step = json['step'];
        if (step is! int) return null;
        return FormEffect(effect: FormEffectType.openStep, step: step);
      default:
        return null;
    }
  }
}

class FormRoute {
  final Condition? when;
  final List<FormEffect> effects;

  const FormRoute({required this.when, required this.effects});

  static FormRoute? tryParse(
    Object? json, {
    required bool requireWhen,
  }) {
    if (json is! Map<String, dynamic>) return null;

    final when = requireWhen ? Condition.tryParse(json['when']) : null;
    if (requireWhen && when == null) return null;

    final rawEffects = json['do'];
    if (rawEffects is! List || rawEffects.isEmpty) return null;

    final effects = <FormEffect>[];
    for (var index = 0; index < rawEffects.length; index++) {
      final effect = FormEffect.tryParse(rawEffects[index]);
      if (effect == null) return null;
      if (effect.effect == FormEffectType.openStep && index != rawEffects.length - 1) {
        return null;
      }
      effects.add(effect);
    }

    return FormRoute(when: when, effects: effects);
  }
}

class FormEventSpec {
  final String type;
  final String name;

  const FormEventSpec({required this.type, required this.name});

  static FormEventSpec? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;

    final type = json['type'];
    final name = json['name'];
    if (type is! String || type.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    return FormEventSpec(type: type, name: name);
  }
}
