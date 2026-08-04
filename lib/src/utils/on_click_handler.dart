import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Action;
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/forms/form_session.dart';
import 'package:gravity_sdk/src/forms/submit_executor.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/action.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';
import 'package:gravity_sdk/src/models/external/campaign.dart';
import 'package:gravity_sdk/src/models/external/tracking_event.dart';

import '../models/internal/campaign_content.dart';
import '../repos/gravity_repo.dart';

class OnClickHandler {
  final CampaignContent content;
  final Campaign campaign;
  final FormSession? session;

  const OnClickHandler({
    required this.content,
    required this.campaign,
    this.session,
  });

  void _callbackTrackingEvent(TrackingEvent event) {
    GravitySDK.instance.gravityEventCallback?.call(event);
  }

  void handeOnClick(
    OnClick onClick,
    BuildContext context, {
    bool explicitClose = false,
  }) {
    try {
      // Unknown never matches: content.events entries with unrecognized types
      // also parse to Action.unknown, and a dead (demoted) button must not
      // fire someone else's tracking URL (spec §3.8).
      final event = onClick.action == Action.unknown
          ? null
          : content.events?.firstWhereOrNull(
              (element) => element.type == onClick.action,
            );
      final closeTrackingOwnedBySession =
          explicitClose &&
          session?.hasFormElements == true &&
          onClick.action == Action.close;
      if (event != null && !closeTrackingOwnedBySession) {
        GravityRepo.instance.triggerEventUrls(event.urls);
      }

      switch (onClick.action) {
        case Action.copy:
          _handleCopyAction(onClick);
        case Action.close:
          _handleCloseAction(onClick);
        case Action.cancel:
          _handleCancelAction(onClick);
        case Action.followUrl:
          _handleFollowUrlAction(onClick);
        case Action.followDeeplink:
          _handleFollowDeeplinkAction(onClick);
        case Action.requestPush:
          _handleRequestPushAction(onClick);
        case Action.openStep:
          GravitySDK.instance.openStep(
            context: context,
            onClick: onClick,
            currentContent: content,
            campaign: campaign,
            session: session,
          );
        case Action.submitForm:
          final formSession = session;
          if (formSession != null) {
            unawaited(
              SubmitExecutor().execute(
                onClick: onClick,
                content: content,
                campaign: campaign,
                session: formSession,
                context: context,
              ),
            );
          }
        default:
      }

      if (explicitClose) finishExplicitClose();
    } catch (e, stackTrace) {
      ErrorReporter.instance.report(
        message: e.toString(),
        level: 'warning',
        section: 'OnClickHandler.handeOnClick',
        stacktrace: stackTrace.toString(),
        extra: {'action': onClick.action.name},
        tags: {'category': 'ui'},
      );
    }
  }

  void finishExplicitClose() {
    session?.finish(
      FormCloseReason.explicitClose,
      content: content,
      campaign: campaign,
    );
  }

  Future<void> _handleCopyAction(OnClick copyAction) async {
    final textToCopy = copyAction.copyData;
    if (textToCopy != null) {
      await Clipboard.setData(ClipboardData(text: textToCopy));
      _callbackTrackingEvent(CopyEvent(textToCopy, content, campaign));
    }
  }

  void _handleCloseAction(OnClick action) {
    //TODO: dismiss callback
  }

  void _handleCancelAction(OnClick action) {
    _callbackTrackingEvent(CancelEvent(content, campaign));
  }

  Future<void> _handleFollowUrlAction(OnClick action) async {
    final url = action.url;
    if (url != null) {
      _callbackTrackingEvent(
        FollowUrlEvent(url, content, campaign, type: action.type),
      );
    }
  }

  Future<void> _handleFollowDeeplinkAction(OnClick action) async {
    final deeplink = action.deeplink;
    if (deeplink != null) {
      _callbackTrackingEvent(FollowDeeplinkEvent(deeplink, content, campaign));
    }
  }

  Future<void> _handleRequestPushAction(OnClick action) async {
    _callbackTrackingEvent(RequestPushEvent(content, campaign));
  }
}
