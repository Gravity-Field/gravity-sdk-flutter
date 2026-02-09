import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
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

  const OnClickHandler({
    required this.content,
    required this.campaign,
  });

  void _callbackTrackingEvent(TrackingEvent event) {
    GravitySDK.instance.gravityEventCallback?.call(event);
  }

  void handeOnClick(OnClick onClick) {
    try {
      final event = content.events?.firstWhereOrNull((element) => element.type == onClick.action);
      if (event != null) {
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
        default:
      }
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

  Future<void> _handleCopyAction(OnClick copyAction) async {
    final textToCopy = copyAction.copyData;
    if (textToCopy != null) {
      await Clipboard.setData(ClipboardData(text: textToCopy));
      _callbackTrackingEvent(CopyEvent(textToCopy, content, campaign));
    }
  }

  Future<void> _handleCloseAction(OnClick action) async {
    //TODO: dismiss callback
  }

  Future<void> _handleCancelAction(OnClick action) async {
    //TODO: dismiss callback
    _callbackTrackingEvent(CancelEvent(content, campaign));
  }

  Future<void> _handleFollowUrlAction(OnClick action) async {
    final url = action.url;
    if (url != null) {
      _callbackTrackingEvent(FollowUrlEvent(url, content, campaign));
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
