import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content_1.dart';

import '../../../data/error_reporting/error_reporter.dart';
import '../../../gravity_sdk.dart';
import '../../../models/external/tracking_event.dart';
import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../utils/content_events_service.dart';
import '../../../utils/modal_impression.dart';
import 'snack_bar_content_2.dart';

abstract class SnackBarContent {
  SnackBarContent();

  CampaignContent? get content => null;
  Campaign? get campaign => null;

  Widget buildContent(BuildContext context, {VoidCallback? onDismiss});

  // The public buildContent callback remains a VoidCallback. The overlay
  // carries its additional close-action detail through an internal scope.
  static void dismiss(BuildContext context, VoidCallback? onDismiss, {bool closeAction = false}) {
    final scope = context.getInheritedWidgetOfExactType<_SnackBarDismissScope>();
    if (scope != null) {
      scope.onDismiss(closeAction);
    } else {
      onDismiss?.call();
    }
  }

  factory SnackBarContent.getSnackBar({
    required TemplateSystemName template,
    required CampaignContent content,
    required Campaign campaign,
  }) {
    return switch (template) {
      TemplateSystemName.snackbar1 => SnackBarContent1(
        campaign: campaign,
        content: content,
      ),
      TemplateSystemName.snackbar2 => SnackBarContent2(
        campaign: campaign,
        content: content,
      ),
      TemplateSystemName.unknown => throw UnimplementedError(),
    };
  }

  static void show({
    required BuildContext context,
    required SnackBarContent snackBarContent,
    required int durationSeconds,
    ModalImpression? impression,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!context.mounted || impression?.valid == false) {
          impression?.closed();
          return;
        }

        final overlay = Overlay.of(context);
        final topOffset = _calculateTopOffset(context);

        late OverlayEntry entry;

        entry = OverlayEntry(
          builder: (_) {
            return _SnackBarOverlay(
              impression: impression,
              topOffset: topOffset,
              durationSeconds: durationSeconds,
              onDismiss: () {
                if (entry.mounted) entry.remove();
              },
              snackBarContent: snackBarContent,
            );
          },
        );

        overlay.insert(entry);
      } catch (error, stackTrace) {
        impression?.closed();
        ErrorReporter.instance.report(
          message: ErrorReporter.messageForError(error),
          level: 'error',
          section: 'SnackBarContent.show',
          stacktrace: stackTrace.toString(),
          tags: const {'category': 'ui'},
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static double _calculateTopOffset(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final ancestorScaffold = Scaffold.maybeOf(context);
    if (ancestorScaffold != null) {
      final height = ancestorScaffold.appBarMaxHeight ?? 0;
      if (height > 0) return height;
    }

    double? childAppBarHeight;
    void visitor(Element element) {
      if (childAppBarHeight != null) return;
      if (element is StatefulElement && element.state is ScaffoldState) {
        final scaffold = element.state as ScaffoldState;
        final height = scaffold.appBarMaxHeight;
        if (height != null && height > 0) {
          childAppBarHeight = height;
        }
      } else {
        element.visitChildren(visitor);
      }
    }

    context.visitChildElements(visitor);

    if (childAppBarHeight != null) return childAppBarHeight!;

    return topPadding;
  }
}

class _SnackBarDismissScope extends InheritedWidget {
  const _SnackBarDismissScope({required this.onDismiss, required super.child});
  final ValueChanged<bool> onDismiss;

  @override
  bool updateShouldNotify(_SnackBarDismissScope oldWidget) => false;
}

class _SnackBarOverlay extends StatefulWidget {
  final ModalImpression? impression;
  final double topOffset;
  final int durationSeconds;
  final VoidCallback onDismiss;
  final SnackBarContent snackBarContent;

  const _SnackBarOverlay({
    this.impression,
    required this.topOffset,
    required this.durationSeconds,
    required this.onDismiss,
    required this.snackBarContent,
  });

  @override
  State<_SnackBarOverlay> createState() => _SnackBarOverlayState();
}

class _SnackBarOverlayState extends State<_SnackBarOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ModalImpression? _impression;
  int? _attachment;
  Timer? _dismissTimer;
  Timer? _visibilityTimer;
  bool _visible = false;
  bool _dismissing = false;
  bool _hasAppeared = false;
  bool _positivePaint = false;
  bool _appearanceScheduled = false;
  final _visibilityKey = UniqueKey();
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final content = widget.snackBarContent.content;
    final campaign = widget.snackBarContent.campaign;
    _impression = widget.impression;
    if (content != null && campaign != null) {
      _impression ??= ContentEventsService.instance.createModalImpression(
        content: content,
        campaign: campaign,
      );
    }
    _attachment = _impression?.attach();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    _dismissTimer = Timer(Duration(seconds: widget.durationSeconds), _dismiss);
  }

  void _contentPainted() {
    if (_hasAppeared || _appearanceScheduled || _dismissing || _controller.value <= 0) return;
    _appearanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appearanceScheduled = false;
      if (!mounted || _controller.value <= 0) return;
      _positivePaint = true;
      _confirmAppearance();
    });
  }

  void _confirmAppearance() {
    if (!mounted || !_positivePaint || _controller.value <= 0 || _hasAppeared ||
        _dismissing || _impression?.valid == false || _impression?.active == false) {
      return;
    }
    _hasAppeared = true;
    final content = widget.snackBarContent.content;
    final campaign = widget.snackBarContent.campaign;
    if (content != null && campaign != null) {
      ContentEventsService.instance.sendContentImpression(
        content: content, campaign: campaign, callbackTrackingEvent: false,
      );
      try {
        GravitySDK.instance.gravityEventCallback?.call(ContentImpressionEvent(content, campaign));
      } catch (_) {}
    }
    _updateVisibility();
  }

  void _dismiss({bool closeAction = false}) {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    _visibilityTimer?.cancel();
    _impression?.closed(attachment: _attachment);
    final content = widget.snackBarContent.content;
    final campaign = widget.snackBarContent.campaign;
    if (_hasAppeared && content != null && campaign != null) {
      ContentEventsService.instance.sendContentClosed(
        content: content,
        campaign: campaign,
        fallbackToCloseEvent: closeAction,
        callbackTrackingEvent: false,
      );
      // Every dismissal has one callback, even without onClose or a matching
      // tracking event. A host callback must not prevent overlay removal.
      try {
        GravitySDK.instance.gravityEventCallback?.call(ContentCloseEvent(content, campaign));
      } catch (_) {}
    }
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  void _updateVisibility() {
    if (!_hasAppeared || !_visible || _dismissing || _impression?.active == false) {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      return;
    }
    if (_impression?.fired == true || _visibilityTimer != null) return;
    // Snackbars keep the native visibility interval, unlike modal first paint.
    // Geometry reports can arrive up to the detector updateInterval later.
    _visibilityTimer = Timer(const Duration(seconds: 1), () {
      _visibilityTimer = null;
      if (mounted && !_dismissing && _visible) _impression?.appeared();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _confirmAppearance();
    _updateVisibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissTimer?.cancel();
    _visibilityTimer?.cancel();
    _impression?.closed(attachment: _attachment);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget contents(BuildContext context) => widget.snackBarContent.buildContent(
      context,
      onDismiss: _dismiss,
    );
    return Positioned(
      top: widget.topOffset + 8,
      left: 16,
      right: 16,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dy < -100) {
            _dismiss();
          }
        },
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: _SnackBarPaintConfirmation(
                onPaint: _contentPainted,
                child: VisibilityDetector(
                key: _visibilityKey,
                onVisibilityChanged: (info) {
                  _visible = info.visibleFraction >= 0.5;
                  _updateVisibility();
                },
                child: _SnackBarDismissScope(
                  onDismiss: (closeAction) => _dismiss(closeAction: closeAction),
                  child: _impression == null
                      ? Builder(builder: contents)
                      : ModalImpressionScope(
                          impression: _impression!,
                          child: Builder(builder: contents),
                        ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Beneath FadeTransition: opacity-zero frames do not paint this child.
class _SnackBarPaintConfirmation extends SingleChildRenderObjectWidget {
  const _SnackBarPaintConfirmation({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) => _SnackBarPaintBox(onPaint);
  @override
  void updateRenderObject(BuildContext context, _SnackBarPaintBox renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _SnackBarPaintBox extends RenderProxyBox {
  _SnackBarPaintBox(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}
