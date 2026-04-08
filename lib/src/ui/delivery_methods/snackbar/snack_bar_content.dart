import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/models/internal/template_system_name.dart';
import 'package:gravity_sdk/src/ui/delivery_methods/snackbar/snack_bar_content_1.dart';

import '../../../models/external/campaign.dart';
import '../../../models/internal/campaign_content.dart';
import 'snack_bar_content_2.dart';

abstract class SnackBarContent {
  SnackBarContent();

  Widget buildContent(BuildContext context, {VoidCallback? onDismiss});

  factory SnackBarContent.getSnackBar({
    required TemplateSystemName template,
    required CampaignContent content,
    required Campaign campaign,
  }) {
    return switch (template) {
      TemplateSystemName.snackbar1 => SnackBarContent1(campaign: campaign, content: content),
      TemplateSystemName.snackbar2 => SnackBarContent2(campaign: campaign, content: content),
      TemplateSystemName.unknown => throw UnimplementedError(),
    };
  }

  static void show({
    required BuildContext context,
    required SnackBarContent snackBarContent,
    required int durationSeconds,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final overlay = Overlay.of(context);
      final topOffset = _calculateTopOffset(context);

      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (_) {
          return _SnackBarOverlay(
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
    });
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

class _SnackBarOverlay extends StatefulWidget {
  final double topOffset;
  final int durationSeconds;
  final VoidCallback onDismiss;
  final SnackBarContent snackBarContent;

  const _SnackBarOverlay({
    required this.topOffset,
    required this.durationSeconds,
    required this.onDismiss,
    required this.snackBarContent,
  });

  @override
  State<_SnackBarOverlay> createState() => _SnackBarOverlayState();
}

class _SnackBarOverlayState extends State<_SnackBarOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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

    Future.delayed(Duration(seconds: widget.durationSeconds), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: widget.snackBarContent.buildContent(context, onDismiss: _dismiss),
            ),
          ),
        ),
      ),
    );
  }
}
