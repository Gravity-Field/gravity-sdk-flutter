import 'dart:async';

import 'package:flutter/widgets.dart';

/// One flag for every detector, close callback and step in one opening.
class ModalImpression {
  ModalImpression({required this.onVisible, this.onUnshownClose, this.isValid});
  final Future<void> Function() onVisible;
  final VoidCallback? onUnshownClose;
  final bool Function()? isValid;
  bool _fired = false;
  bool _closed = false;
  bool _stepTransition = false;
  int _attachment = 0;
  VoidCallback? _confirmExplicitClose;

  bool get fired => _fired;
  bool get valid => isValid?.call() != false;
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

  void beginStep() => _stepTransition = true;
  int attach({VoidCallback? confirmClose}) {
    _confirmExplicitClose = confirmClose;
    _stepTransition = false;
    return ++_attachment;
  }

  void closed({int? attachment}) {
    if (attachment != null && attachment != _attachment) return;
    if (_stepTransition || _closed) return;
    _closed = true;
    _confirmExplicitClose = null;
    if (!_fired) onUnshownClose?.call();
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
