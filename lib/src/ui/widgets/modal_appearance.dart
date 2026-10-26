import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gravity_sdk/src/utils/modal_impression.dart';

/// Confirms actual content paint, independently of VisibilityDetector's batch
/// interval. Place inside Dialog/Scaffold, never around the modal scrim.
class ModalAppearance extends StatefulWidget {
  const ModalAppearance({
    super.key,
    required this.impression,
    required this.child,
  });
  final ModalImpression impression;
  final Widget child;
  @override
  State<ModalAppearance> createState() => _ModalAppearanceState();
}

class _ModalAppearanceState extends State<ModalAppearance>
    with WidgetsBindingObserver {
  bool _paintConfirmed = false;
  bool _checking = false;
  late final int _attachment;
  @override
  void initState() {
    super.initState();
    _attachment = widget.impression.attach();
    WidgetsBinding.instance.addObserver(this);
  }

  void _painted() {
    _paintConfirmed = true;
    if (_checking) return;
    _checkFrame();
  }

  void _checkFrame() {
    _checking = false;
    if (!mounted ||
        widget.impression.fired ||
        widget.impression.closedBeforeAppearance) {
      return;
    }
    if (!widget.impression.valid) {
      _cancelUnshown();
      return;
    }
    // A paint at animation value 0 may be cached by a retained layer. Keep
    // checking subsequent animation frames even if the child is not repainted.
    _checking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _paintConfirmed) _checkFrame();
    });
    final route = ModalRoute.of(context);
    if (route != null &&
        (!route.isCurrent ||
            route.animation?.status == AnimationStatus.reverse ||
            (route.animation?.value ?? 1) == 0)) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    if (!rect.overlaps(Offset.zero & MediaQuery.sizeOf(context))) return;
    widget.impression.appeared();
  }

  void _cancelUnshown() {
    widget.impression.closed(attachment: _attachment);
    // A cancelled opening must not remain visible with its reservation
    // released and its impression disabled, including after foregrounding.
    final route = ModalRoute.of(context);
    if (route != null && !route.isFirst && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !widget.impression.fired) {
      _cancelUnshown();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.impression.closed(
      attachment: _attachment,
    ); // Disposal itself never confirms visibility.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.impression.fired && !widget.impression.valid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cancelUnshown();
      });
      return const SizedBox.shrink();
    }
    return ModalImpressionScope(
      impression: widget.impression,
      child: PopScope<Object?>(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) widget.impression.explicitClose();
        },
        child: _PaintConfirmation(onPaint: _painted, child: widget.child),
      ),
    );
  }
}

class _PaintConfirmation extends SingleChildRenderObjectWidget {
  const _PaintConfirmation({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintConfirmationBox(onPaint);
  @override
  void updateRenderObject(
    BuildContext context,
    _PaintConfirmationBox renderObject,
  ) => renderObject.onPaint = onPaint;
}

class _PaintConfirmationBox extends RenderProxyBox {
  _PaintConfirmationBox(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onPaint();
    });
  }
}
