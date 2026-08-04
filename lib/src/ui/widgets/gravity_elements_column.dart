import 'package:flutter/material.dart' hide Action, Element;

import '../../data/error_reporting/error_reporter.dart';
import '../../forms/condition_evaluator.dart';
import '../../forms/form_session.dart';
import '../../forms/input_validity.dart';
import '../../models/actions/action.dart';
import '../../models/actions/on_click.dart';
import '../../models/external/campaign.dart';
import '../../models/internal/campaign_content.dart';
import '../../models/internal/element.dart';
import '../../models/internal/products.dart';
import '../elements/gravity_element.dart';

class GravityElementsColumn extends StatelessWidget {
  const GravityElementsColumn({
    super.key,
    required this.content,
    required this.campaign,
    required this.onClickCallback,
    this.session,
    this.formsEnabled = false,
    this.products,
    this.elements,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
  });

  final CampaignContent content;
  final Campaign campaign;
  final void Function(Element element, OnClick onClick) onClickCallback;
  final FormSession? session;
  final bool formsEnabled;
  final Products? products;
  final List<Element>? elements;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  /// Conditional elements grow/shrink with a fade instead of popping in.
  static const visibilityAnimationDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final contentElements =
        elements ?? content.variables.elements ?? const <Element>[];
    final formSession = session;

    if (formSession == null) return _buildColumn(contentElements, null);

    return ListenableBuilder(
      listenable: formSession,
      builder: (context, child) => _buildColumn(contentElements, formSession),
    );
  }

  Widget _buildColumn(List<Element> allElements, FormSession? formSession) {
    if (!formsEnabled && allElements.any(_isFormElement)) {
      ErrorReporter.instance.report(
        message: 'Form elements are disabled for this delivery method',
        level: 'warning',
        section: 'GravityElementsColumn.build',
        tags: {'category': 'forms'},
      );
    }

    final renderedElements = (formsEnabled
            ? allElements
            : allElements.where((element) => !element.isFormInput))
        .toList();
    final visibleElements = formSession == null
        ? renderedElements
        : formSession.visibleElements(renderedElements);

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: renderedElements.map((element) {
        final condition = element.visibleWhen;
        if (formSession == null || condition == null) {
          return _elementWidget(element, visibleElements);
        }
        final visible = evaluateCondition(condition, formSession.stateView);
        // Buttons come in complementary visibleWhen pairs («Не сейчас» /
        // «Отправить») and must swap in place instantly — a size animation
        // makes the incoming button crawl in from below the outgoing one.
        if (element.type == ElementType.button) {
          return visible
              ? _elementWidget(element, visibleElements)
              : const SizedBox.shrink();
        }
        // Other conditional elements keep a stable slot in the column and
        // animate between content and a collapsed placeholder, so
        // state-driven appearance is smooth rather than an instant jump.
        return AnimatedSwitcher(
          duration: visibilityAnimationDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: AlignmentDirectional.topCenter,
              child: child,
            ),
          ),
          child: visible
              ? _elementWidget(element, visibleElements)
              : const SizedBox.shrink(),
        );
      }).toList(),
    );
  }

  Widget _elementWidget(Element element, List<Element> visibleElements) {
    return GravityElement(
      content: content,
      campaign: campaign,
      element: element,
      products: products,
      session: session,
      formsEnabled: formsEnabled,
      enabled: _isEnabled(element, visibleElements),
      onClickCallback: (onClick) {
        if (!formsEnabled && onClick.action == Action.submitForm) {
          return;
        }
        onClickCallback(element, onClick);
      },
    ).getWidget();
  }

  bool _isFormElement(Element element) {
    return element.isFormInput ||
        (element.type == ElementType.button &&
            element.onClick?.action == Action.submitForm);
  }

  bool _isEnabled(Element element, List<Element> visibleElements) {
    if (element.type != ElementType.button ||
        element.onClick?.action != Action.submitForm) {
      return true;
    }

    final formSession = session;
    if (!formsEnabled ||
        formSession == null ||
        formSession.isSubmitting ||
        formSession.isFinished) {
      return false;
    }

    return visibleElements.where((element) => element.isFormInput).every(
      (element) =>
          isInputValueValid(element, formSession.valueOf(element.attributeName!)),
    );
  }
}

/// Action-level auto-close gate: submitForm and unknown are dead buttons per
/// spec §2.3 regardless of closeOnClick; openStep replaces the content itself.
bool shouldAutoCloseOnClick(OnClick onClick) {
  return onClick.closeOnClick &&
      onClick.action != Action.openStep &&
      onClick.action != Action.submitForm &&
      onClick.action != Action.unknown;
}

/// Button-scoped variant for modal/bottom sheet/full screen, which always
/// auto-popped only on button clicks. Tooltip and snackbar images historically
/// dismiss on any clickable element — they use [shouldAutoCloseOnClick].
bool shouldAutoPopOnClick(Element element, OnClick onClick) {
  return element.type == ElementType.button && shouldAutoCloseOnClick(onClick);
}
