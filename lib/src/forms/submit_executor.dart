import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart' hide Action, Element;

import '../gravity_sdk.dart';
import '../models/actions/action.dart';
import '../models/actions/form_action.dart';
import '../models/actions/on_click.dart';
import '../models/external/campaign.dart';
import '../models/external/tracking_event.dart';
import '../models/external/trigger_event.dart';
import '../models/internal/campaign_content.dart';
import '../models/internal/element.dart';
import '../repos/gravity_repo.dart';
import '../utils/logger.dart';
import 'condition_evaluator.dart';
import 'form_session.dart';
import 'input_validity.dart';

/// Executes a structurally valid `submit_form` click: snapshot of the visible
/// inputs -> validity re-check (required, minLength) -> fire-and-forget event
/// -> first-match route -> effects (spec §3.2–§3.5). Never throws.
class SubmitExecutor {
  Future<void> execute({
    required OnClick onClick,
    required CampaignContent content,
    required Campaign campaign,
    required FormSession session,
    required BuildContext context,
  }) async {
    if (session.isSubmitting || session.isFinished) return;

    final event = onClick.event;
    final defaultRoute = onClick.defaultRoute;
    // Structural validation demotes malformed submit_form to unknown at parse
    // time; a null here means the caller bypassed it — treat as dead button.
    if (event == null || defaultRoute == null) return;

    final visible = session.visibleElements(
      content.variables.elements ?? const <Element>[],
    );
    final visibleInputs = visible.where((e) => e.isFormInput).toList();
    final snapshot = <String, Object?>{
      for (final input in visibleInputs)
        input.attributeName!: session.valueOf(input.attributeName!),
    };

    final invalidInput = visibleInputs.any(
      (input) => !isInputValueValid(input, snapshot[input.attributeName]),
    );
    if (invalidInput) return;

    session.beginSubmit();
    try {
      final props = <String, String>{
        for (final entry in snapshot.entries) entry.key: _serialize(entry.value),
      };
      // Fire-and-forget (spec §3.4): the repo reports and rethrows, so the
      // error must be swallowed here or it becomes an unhandled async error.
      unawaited(
        GravityRepo.instance
            .event(
              events: [
                CustomEvent(type: event.type, name: event.name, customProps: props),
              ],
              customUser: GravitySDK.instance.user,
              pageContext: session.pageContext,
              options: GravitySDK.instance.options,
            )
            .then<void>((_) {})
            .catchError((_) {}),
      );

      final route =
          onClick.routes?.firstWhereOrNull(
            (route) =>
                route.when != null && evaluateCondition(route.when!, snapshot),
          ) ??
          defaultRoute;
      _runEffects(
        route.effects,
        content: content,
        campaign: campaign,
        session: session,
        context: context,
      );
    } finally {
      session.endSubmit();
    }
  }

  void _runEffects(
    List<FormEffect> effects, {
    required CampaignContent content,
    required Campaign campaign,
    required FormSession session,
    required BuildContext context,
  }) {
    for (var index = 0; index < effects.length; index++) {
      if (session.isFinished && index > 0) {
        talker.warning(
          'submit_form: session already finished, remaining effects ignored',
        );
        return;
      }
      final effect = effects[index];
      var terminal = true;
      switch (effect.effect) {
        case FormEffectType.close:
          _finishAndPop(session, content, campaign, context);
        case FormEffectType.openUrl:
          _finishAndPop(session, content, campaign, context);
          GravitySDK.instance.gravityEventCallback?.call(
            FollowUrlEvent(effect.url!, content, campaign, type: effect.urlType),
          );
        case FormEffectType.openDeeplink:
          _finishAndPop(session, content, campaign, context);
          GravitySDK.instance.gravityEventCallback?.call(
            FollowDeeplinkEvent(effect.deeplink!, content, campaign),
          );
        case FormEffectType.openStep:
          terminal = false;
          GravitySDK.instance.openStep(
            context: context,
            onClick: OnClick(action: Action.openStep, step: effect.step),
            currentContent: content,
            campaign: campaign,
            session: session,
          );
      }
      if (terminal && index < effects.length - 1) {
        talker.warning(
          'submit_form: terminal effect ${effect.effect.name} is not last, '
          'the remaining effects are ignored',
        );
        return;
      }
    }
  }

  void _finishAndPop(
    FormSession session,
    CampaignContent content,
    Campaign campaign,
    BuildContext context,
  ) {
    final won = session.finish(
      FormCloseReason.submitted,
      content: content,
      campaign: campaign,
    );
    if (won && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  String _serialize(Object? value) {
    if (value == null) return '';
    if (value is num) {
      // "4", never "4.0" — the three SDKs must agree on the wire format.
      if (value % 1 == 0) return value.toInt().toString();
      return value.toString();
    }
    return value.toString();
  }
}
