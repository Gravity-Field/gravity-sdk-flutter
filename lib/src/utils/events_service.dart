import 'package:gravity_sdk/src/repos/gravity_repo.dart';

import '../models/content.dart';
import '../models/action.dart';
import 'package:collection/collection.dart';

import '../models/event.dart';

class ContentEventsService {
  ContentEventsService._();

  static final ContentEventsService instance = ContentEventsService._();

  sendContentLoaded(Content content) {
    print('sendContentLoaded');
    final onLoad = content.variables.onLoad;
    final events = content.events;
    _handleAction(onLoad, events);
  }

  sendContentImpression(Content content) {
    print('sendContentImpression');
    final onImpression = content.variables.onImpression;
    final events = content.events;
    _handleAction(onImpression, events);
  }

  sendContentVisibleImpression(Content content) {
    print('sendContentVisibleImpression');
    final onVisibleImpression = content.variables.onVisibleImpression;
    final events = content.events;
    _handleAction(onVisibleImpression, events);
  }

  sendContentClosed(Content content) {
    print('sendContentClosed');
    final onClose = content.variables.onClose;
    final events = content.events;
    _handleAction(onClose, events);
  }

  void _handleAction(Action? action, List<Event> events) {
    if (action == null) return;

    final event = events.firstWhereOrNull((event) => event.name == action.action);

    if (event == null) return;

    final urls = event.urls;

    GravityRepo.instance.triggerEventUrls(urls);
  }
}
