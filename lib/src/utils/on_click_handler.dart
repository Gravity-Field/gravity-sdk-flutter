import 'package:flutter/material.dart' hide Action;
import 'package:collection/collection.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/actions/on_click.dart';

import '../models/actions/event.dart';
import '../repos/gravity_repo.dart';

class OnClickHandler {
  final List<Event> _events;

  const OnClickHandler(
    this._events,
  );

  void handeOnClick(OnClick onClick) {
    print('handeOnClick: ${onClick.action}');
    final event = _events.firstWhereOrNull((element) => element.name == onClick.action);
    if (event != null) {
      GravityRepo.instance.triggerEventUrls(event.urls);
    }

    print('trigger global on click callback');

    GravitySDK.instance.globalOnClickCallback?.call(onClick);
  }
}
