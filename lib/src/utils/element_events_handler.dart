import 'package:flutter/material.dart' hide Action;
import 'package:collection/collection.dart';

import '../models/internal/event.dart';
import '../models/internal/action.dart';
import '../repos/gravity_repo.dart';

class ElementEventsHandler {
  final List<Event> _events;

  const ElementEventsHandler(
    this._events,
  );

  void handleAction(Action action) {
    print('handleAction: ${action.action}');
    final event = _events.firstWhereOrNull((element) => element.name == action.action);
    if (event != null) {
      GravityRepo.instance.triggerEventUrls(event.urls);
    }
  }
}
