import 'package:collection/collection.dart';
import 'package:gravity_sdk/src/repos/gravity_repo.dart';

import '../models/actions/content_action.dart';
import '../models/internal/campaign_content.dart';
import '../models/actions/event.dart';

class ContentEventsService {
  ContentEventsService._();

  static final ContentEventsService instance = ContentEventsService._();

  sendContentLoaded(CampaignContent content) {
    print('sendContentLoaded');
    final onLoad = content.variables.onLoad;
    final events = content.events;
    _handleAction(onLoad, events);
  }

  sendContentImpression(CampaignContent content) {
    print('sendContentImpression');
    final onImpression = content.variables.onImpression;
    final events = content.events;
    _handleAction(onImpression, events);
  }

  sendContentVisibleImpression(CampaignContent content) {
    print('sendContentVisibleImpression');
    final onVisibleImpression = content.variables.onVisibleImpression;
    final events = content.events;
    _handleAction(onVisibleImpression, events);
  }

  sendContentClosed(CampaignContent content) {
    print('sendContentClosed');
    final onClose = content.variables.onClose;
    final events = content.events;
    _handleAction(onClose, events);
  }

  void _handleAction(ContentAction? action, List<Event> events) {
    if (action == null) return;

    final event = events.firstWhereOrNull((event) => event.name == action.action);

    if (event == null) return;

    final urls = event.urls;

    GravityRepo.instance.triggerEventUrls(urls);
  }
}
