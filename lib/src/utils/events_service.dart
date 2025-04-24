import 'package:gravity_sdk/src/repos/gravity_repo.dart';

import '../models/content.dart';
import 'package:collection/collection.dart';

class EventsService {
  EventsService._();

  static final EventsService instance = EventsService._();

  static sendContentLoaded(Content content) {
    final onLoad = content.variables.onLoad;

    if (onLoad == null) return;

    final event = content.events.firstWhereOrNull((event) => event.name == onLoad.action);

    if (event == null) return;

    final urls = event.urls;

    GravityRepo.instance.triggerEventUrls(urls);
  }
}
