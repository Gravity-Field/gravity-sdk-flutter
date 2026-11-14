import 'dart:async';

import 'package:flutter/widgets.dart';

/// One flag for every detector, close callback and step in one opening.
class ModalImpression {
  ModalImpression({required this.onVisible, this.onUnshownClose, this.isValid, this.isValidWhileAttached, this.onAttached, this.onDetached});
  final Future<void> Function() onVisible;
  final VoidCallback? onUnshownClose;
  final VoidCallback? onAttached;
  final VoidCallback? onDetached;
  final bool Function()? isValid;
  // Attached snackbars outlive screen reservations, but never user changes.
  final bool Function()? isValidWhileAttached;
  bool _fired = false;
  bool _closed = false;
  bool _stepTransition = false;
  int _attachment = 0;
  VoidCallback? _confirmExplicitClose;
  VoidCallback? _onUnattachedStepClose;

  // Live route protection is independent of WRIMP persistence and its timeout.
  // A step reuses this opening; an unrelated attempt cannot claim the same key.
  static final _presentations = <String, ModalImpression>{};
  String? _presentationKey;
  WeakReference<NavigatorState>? _presentationNavigator;

  bool claimPresentation(String campaignId, NavigatorState navigator) {
    if (_closed) return false;
    // A Navigator can be disposed before the route builder ever mounts, so
    // neither ModalAppearance.dispose nor the route's popped future may run.
    _presentations.removeWhere((_, opening) => opening._presentationNavigator?.target?.mounted != true);
    final key = campaignId;
    final owner = _presentations[key];
    if (owner != null && !identical(owner, this)) return false;
    final previous = _presentationKey;
    if (previous != null && previous != key && identical(_presentations[previous], this)) {
      _presentations.remove(previous);
    }
    _presentationKey = key;
    _presentationNavigator = WeakReference(navigator);
    _presentations[key] = this;
    return true;
  }

  bool get fired => _fired;
  bool get valid => (_attachment > 0 ? isValidWhileAttached ?? isValid : isValid)?.call() != false;
  bool get closedBeforeAppearance => _closed && !_fired;
  bool get active =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void appeared() {
    if (_closed || !active || !valid) return;
    _fire();
  }

  void explicitClose() {
    if (!_closed && !_fired && active && valid) _confirmExplicitClose?.call();
  }

  void _fire() {
    if (_fired) return;
    _fired = true; // Synchronous: no callback can race persistence.
    unawaited(onVisible());
  }

  void beginStep({VoidCallback? onUnattachedClose}) {
    _stepTransition = true;
    _onUnattachedStepClose = onUnattachedClose;
  }

  // The old route has been dismissed. Its disposal must not close the new
  // attempt, even if that attempt fails or closes before its first build.
  void endStepTransition() {
    if (!_stepTransition) return;
    _stepTransition = false;
    _confirmExplicitClose = null;
    _attachment++;
  }
  int attach({VoidCallback? confirmClose}) {
    _confirmExplicitClose = confirmClose;
    _stepTransition = false;
    _onUnattachedStepClose = null;
    onAttached?.call();
    return ++_attachment;
  }

  void closed({int? attachment}) {
    if (attachment != null && attachment != _attachment) return;
    if (_stepTransition || _closed) return;
    _closed = true;
    final key = _presentationKey;
    if (key != null && identical(_presentations[key], this)) {
      _presentations.remove(key);
    }
    _confirmExplicitClose = null;
    onDetached?.call();
    if (!_fired) onUnshownClose?.call();
    final onUnattachedClose = _onUnattachedStepClose;
    _onUnattachedStepClose = null;
    onUnattachedClose?.call();
  }
}

class ModalImpressionScope extends InheritedWidget {
  const ModalImpressionScope({
    super.key,
    required this.impression,
    required super.child,
  });
  final ModalImpression impression;
  static ModalImpression? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ModalImpressionScope>()?.impression;
  @override
  bool updateShouldNotify(ModalImpressionScope oldWidget) =>
      impression != oldWidget.impression;
}
