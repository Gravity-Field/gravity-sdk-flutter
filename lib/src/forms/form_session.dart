import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/actions/action.dart';
import '../models/external/campaign.dart';
import '../models/external/page_context.dart';
import '../models/internal/campaign_content.dart';
import '../models/internal/element.dart';
import '../utils/content_events_service.dart';
import 'condition_evaluator.dart';

enum FormCloseReason { submitted, explicitClose, dismiss }

class FormSession extends ChangeNotifier {
  FormSession({required this.pageContext, required this.hasFormElements});

  final PageContext pageContext;
  final bool hasFormElements;

  final Map<String, Object?> _state = {};
  var _isFinished = false;
  var _isSubmitting = false;
  var _pendingStepTransitions = 0;

  bool get isFinished => _isFinished;

  bool get isSubmitting => _isSubmitting;

  Object? valueOf(String attributeName) => _state[attributeName];

  void setValue(String attributeName, Object? value) {
    _state[attributeName] = value;
    notifyListeners();
  }

  Map<String, Object?> get stateView => UnmodifiableMapView(_state);

  void beginSubmit() {
    _isSubmitting = true;
    notifyListeners();
  }

  void endSubmit() {
    _isSubmitting = false;
    notifyListeners();
  }

  void beginStepTransition() {
    _pendingStepTransitions++;
  }

  bool consumeStepTransition() {
    if (_pendingStepTransitions == 0) return false;
    _pendingStepTransitions--;
    return true;
  }

  bool finish(
    FormCloseReason reason, {
    required CampaignContent content,
    required Campaign campaign,
  }) {
    if (_isFinished) return false;
    _isFinished = true;

    if (hasFormElements) {
      ContentEventsService.instance.sendContentClosed(
        content: content,
        campaign: campaign,
      );
    }
    return true;
  }

  List<Element> visibleElements(List<Element> elements) => elements
      .where(
        (element) =>
            element.visibleWhen == null ||
            evaluateCondition(element.visibleWhen!, stateView),
      )
      .toList();
}

bool campaignHasFormElements(Campaign campaign) {
  return campaign.payload.any(
    (variation) => variation.contents.any(
      (content) => (content.variables.elements ?? const <Element>[]).any(
        (element) =>
            element.isFormInput ||
            (element.type == ElementType.button &&
                element.onClick?.action == Action.submitForm),
      ),
    ),
  );
}
