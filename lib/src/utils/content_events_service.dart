import 'package:collection/collection.dart';
import 'package:gravity_sdk/src/utils/modal_impression.dart';
import 'package:gravity_sdk/src/utils/in_app_presentation_gate.dart';
import 'package:gravity_sdk/src/data/session/session_manager.dart';
import 'package:gravity_sdk/gravity_sdk.dart';
import 'package:gravity_sdk/src/data/error_reporting/error_reporter.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';

class ContentEventsService {
  ContentEventsService._();

  static const contentClickEventType = 'click';

  static final ContentEventsService instance = ContentEventsService._();

  ModalImpression createModalImpression({
    required CampaignContent content,
    required Campaign campaign,
    PresentationReservation? reservation,
    bool Function()? isValid,
  }) {
    final sdk = GravitySDK.instance;
    final user =
        sdk.user ??
        SessionManager.instance.getCachedUser() ??
        SessionManager.instance.observedUser;
    final section = sdk.section;
    final apiKey = sdk.apiKey;
    final scope =
        reservation?.scope ?? GravityRepo.impressionScope(section, user);
    final campaignId =
        reservation?.campaignId ?? campaign.payload.first.campaignId;
    // Snapshot root URLs before OPEN_STEP can replace the content.
    final urls =
        content.events
            ?.where((e) => e.type == Action.visibleImpression)
            .expand((e) => e.urls)
            .toSet()
            .toList() ??
        <String>[];
    return ModalImpression(
      isValid: isValid,
      onUnshownClose: reservation == null ? null : () => InAppPresentationGate.instance.cancel(reservation),
      onVisible: () async {
        try {
          if (reservation != null) InAppPresentationGate.instance.visible(reservation);
          if (urls.isEmpty) {
            ErrorReporter.instance.report(
              message: 'Modal visible_impression has no tracking URLs',
              level: 'warning',
              section: 'ContentEventsService',
              tags: const {'category': 'tracking'},
            );
            return;
          }
          await GravityRepo.instance.queueModalImpression(
            urls: urls,
            scope: scope,
            campaignId: campaignId,
            user: user,
            section: section,
            apiKey: apiKey,
            reservationToken: reservation?.token,
          );
          sdk.gravityEventCallback?.call(
            ContentVisibleImpressionEvent(content, campaign),
          );
        } catch (error, stackTrace) {
          ErrorReporter.instance.report(
            message: error.toString(),
            level: 'warning',
            section: 'ContentEventsService.modalVisibleImpression',
            stacktrace: stackTrace.toString(),
            tags: const {'category': 'tracking'},
          );
        }
      },
    );
  }

  void sendContentLoaded({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onLoad = content.variables.onLoad;
    _trackEvent(
      action: onLoad,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendContentImpression({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onImpression = content.variables.onImpression;
    _trackEvent(
      action: onImpression,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendContentVisibleImpression({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onVisibleImpression = content.variables.onVisibleImpression;
    _trackEvent(
      action: onVisibleImpression,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  void sendContentClosed({
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    final onClose = content.variables.onClose;
    _trackEvent(
      action: onClose,
      content: content,
      campaign: campaign,
      callbackTrackingEvent: callbackTrackingEvent,
    );
  }

  /// `click` deliberately has no [Action] member: [OnClickHandler] treats
  /// [Action.unknown] as "do nothing", so adding it would activate every
  /// button configured with `action: "click"`.
  void sendContentClick({
    required CampaignContent content,
    required Campaign campaign,
  }) {
    try {
      final event = content.events?.firstWhereOrNull(
        (event) => event.rawType == contentClickEventType,
      );
      if (event == null) return;

      GravityRepo.instance.triggerEventUrls(event.urls);
    } catch (e, stackTrace) {
      ErrorReporter.instance.report(
        message: e.toString(),
        level: 'warning',
        section: 'ContentEventsService.sendContentClick',
        stacktrace: stackTrace.toString(),
        tags: {'category': 'tracking'},
      );
    }
  }

  void _trackEvent({
    required ContentAction? action,
    required CampaignContent content,
    required Campaign campaign,
    bool callbackTrackingEvent = true,
  }) {
    try {
      if (action == null) return;
      // Unknown actions must not match unknown event types such as `click`.
      if (action.action == Action.unknown) return;

      final event = content.events?.firstWhereOrNull((event) => event.type == action.action);

      if (event == null) return;

      final urls = event.urls;

      GravityRepo.instance.triggerEventUrls(urls);

      if (callbackTrackingEvent) {
        final event = switch (action.action) {
          Action.load => ContentLoadEvent(content, campaign),
          Action.impression => ContentImpressionEvent(content, campaign),
          Action.visibleImpression => ContentVisibleImpressionEvent(content, campaign),
          Action.close => ContentCloseEvent(content, campaign),
          _ => null,
        };

        if (event != null) {
          GravitySDK.instance.gravityEventCallback?.call(event);
        }
      }
    } catch (e, stackTrace) {
      ErrorReporter.instance.report(
        message: e.toString(),
        level: 'warning',
        section: 'ContentEventsService._trackEvent',
        stacktrace: stackTrace.toString(),
        tags: {'category': 'tracking'},
      );
    }
  }
}
