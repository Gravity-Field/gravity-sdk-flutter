import 'package:flutter/material.dart';
import 'package:gravity_sdk/src/gravity_sdk.dart';
import 'package:gravity_sdk/src/models/external/page_context.dart';

import 'anchor_registry.dart';

typedef GravityAnchorBuilder = Widget Function(BuildContext context, VoidCallback onReady);

/// A wrapper widget that marks UI elements as anchor points
/// for Tooltip campaigns.
///
/// Usage example:
/// ```dart
/// GravityAnchor(
///   selector: "btnSaveProfile",
///   builder: (context, onReady) {
///     return MyWidget(
///       onLoaded: onReady,
///     );
///   },
/// )
/// ```
class GravityAnchor extends StatefulWidget {
  final String selector;
  final GravityAnchorBuilder builder;
  final PageContext? pageContext;

  const GravityAnchor({super.key, required this.selector, required this.builder, this.pageContext});

  @override
  State<GravityAnchor> createState() => _GravityAnchorState();
}

class _GravityAnchorState extends State<GravityAnchor> {
  final GlobalKey _anchorKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  bool _hasRequestedContent = false;

  @override
  void initState() {
    super.initState();
    AnchorRegistry.instance.register(widget.selector, _anchorKey, _layerLink);
  }

  @override
  void didUpdateWidget(GravityAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selector != widget.selector) {
      AnchorRegistry.instance.unregister(oldWidget.selector);
      AnchorRegistry.instance.register(widget.selector, _anchorKey, _layerLink);
      _hasRequestedContent = false;
    }
  }

  @override
  void dispose() {
    AnchorRegistry.instance.unregister(widget.selector);
    super.dispose();
  }

  void _onReady() {
    if (_hasRequestedContent) return;
    _hasRequestedContent = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GravitySDK.instance.fetchAnchorContent(
          context: context,
          selector: widget.selector,
          pageContext: widget.pageContext,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(key: _anchorKey, child: widget.builder(context, _onReady)),
    );
  }
}
