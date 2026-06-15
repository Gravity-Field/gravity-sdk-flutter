import 'dart:async';

import 'package:flutter/material.dart' hide Action;
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/actions/action.dart';
import '../../../models/external/campaign.dart';
import '../../../models/internal/arrow.dart';
import '../../../models/internal/campaign_content.dart';
import '../../../models/internal/tooltip_config.dart';
import '../../../models/internal/tooltip_positioning.dart';
import '../../../utils/content_events_service.dart';
import '../../../utils/on_click_handler.dart';
import '../../anchor/anchor_registry.dart';
import '../../elements/gravity_element.dart';
import 'tooltip_arrow_painter.dart';

class TooltipContent extends StatefulWidget {
  final CampaignContent content;
  final Campaign campaign;
  final TooltipConfig config;
  final String selector;
  final VoidCallback onDismiss;

  const TooltipContent({
    super.key,
    required this.content,
    required this.campaign,
    required this.config,
    required this.selector,
    required this.onDismiss,
  });

  @override
  State<TooltipContent> createState() => _TooltipContentState();
}

class _TooltipContentState extends State<TooltipContent> {
  late final OnClickHandler onClickHandler;
  bool _hasBeenVisible = false;
  Rect? _anchorRect;
  TooltipDirection _resolvedDirection = TooltipDirection.bottom;
  int _retryCount = 0;
  Timer? _retryTimer;
  static const int _maxRetries = 5;
  static const double _minFlipSpace = 80.0;

  TooltipPositioning? get _positioning => widget.content.variables.positioning;

  Arrow? get _arrow => widget.content.variables.frameUI?.arrow;

  TooltipDirection get _effectiveDirection => _positioning?.effectiveDirection ?? _directionFromConfig();

  TooltipAlignment get _effectiveAlignment => _positioning?.effectiveAlignment ?? TooltipAlignment.center;

  double get _effectiveOffset => _positioning?.effectiveOffset ?? widget.config.effectiveDistance;

  bool get _effectiveAllowFlip => _positioning?.effectiveAllowFlip ?? true;

  ArrowAlignment get _effectiveArrowAlignment => _arrow?.effectiveAlignment ?? _arrowAlignmentFromConfig();

  double get _effectiveArrowWidth => _arrow?.effectiveWidth ?? 16.0;
  double get _effectiveArrowHeight => _arrow?.effectiveHeight ?? 8.0;

  Color? get _effectiveArrowColor => _arrow?.color;

  TooltipDirection _directionFromConfig() {
    return switch (widget.config.effectivePosition) {
      TooltipPosition.top => TooltipDirection.top,
      TooltipPosition.bottom => TooltipDirection.bottom,
      TooltipPosition.left => TooltipDirection.left,
      TooltipPosition.right => TooltipDirection.right,
      TooltipPosition.auto => TooltipDirection.bottom,
    };
  }

  ArrowAlignment _arrowAlignmentFromConfig() {
    return switch (widget.config.effectiveArrowPosition) {
      ArrowPosition.start => ArrowAlignment.start,
      ArrowPosition.center => ArrowAlignment.center,
      ArrowPosition.end => ArrowAlignment.end,
    };
  }

  @override
  void initState() {
    super.initState();

    onClickHandler = OnClickHandler(campaign: widget.campaign, content: widget.content);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAnchorData();

      ContentEventsService.instance.sendContentImpression(campaign: widget.campaign, content: widget.content);
    });
  }

  void _updateAnchorData() {
    final anchorRect = AnchorRegistry.instance.getAnchorRect(widget.selector);

    if (anchorRect != null && mounted) {
      setState(() {
        _anchorRect = anchorRect;
        _resolvedDirection = _resolveDirection(anchorRect);
      });
    } else if (_retryCount < _maxRetries && mounted) {
      _retryCount++;
      _retryTimer = Timer(const Duration(milliseconds: 50), () {
        if (mounted) _updateAnchorData();
      });
    }
  }

  TooltipDirection _resolveDirection(Rect anchorRect) {
    final preferredDirection = _effectiveDirection;

    if (!_effectiveAllowFlip) {
      return preferredDirection;
    }

    final screenSize = MediaQuery.of(context).size;
    final spaceTop = anchorRect.top;
    final spaceBottom = screenSize.height - anchorRect.bottom;
    final spaceLeft = anchorRect.left;
    final spaceRight = screenSize.width - anchorRect.right;

    switch (preferredDirection) {
      case TooltipDirection.top:
        if (spaceTop >= _minFlipSpace) return TooltipDirection.top;
        if (spaceBottom >= _minFlipSpace) return TooltipDirection.bottom;
        break;
      case TooltipDirection.bottom:
        if (spaceBottom >= _minFlipSpace) return TooltipDirection.bottom;
        if (spaceTop >= _minFlipSpace) return TooltipDirection.top;
        break;
      case TooltipDirection.left:
        if (spaceLeft >= _minFlipSpace) return TooltipDirection.left;
        if (spaceRight >= _minFlipSpace) return TooltipDirection.right;
        break;
      case TooltipDirection.right:
        if (spaceRight >= _minFlipSpace) return TooltipDirection.right;
        if (spaceLeft >= _minFlipSpace) return TooltipDirection.left;
        break;
    }

    return preferredDirection;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_anchorRect == null) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final tooltip = _buildTooltipWithArrow(context);

    return Stack(
      children: [
        _positionedTooltip(screenSize, tooltip),
      ],
    );
  }

  Widget _positionedTooltip(Size screenSize, Widget tooltip) {
    final rect = _anchorRect!;
    final offset = _effectiveOffset;
    final isVertical = _resolvedDirection == TooltipDirection.top || _resolvedDirection == TooltipDirection.bottom;

    final tooltipChild = VisibilityDetector(
      key: ValueKey(widget.content.contentId),
      onVisibilityChanged: (info) {
        if (_hasBeenVisible) return;
        if (info.visibleFraction >= 0.5) {
          _hasBeenVisible = true;
          ContentEventsService.instance.sendContentVisibleImpression(
            campaign: widget.campaign,
            content: widget.content,
          );
        }
      },
      child: tooltip,
    );

    final (anchorPoint, fracTranslation) = _getAlignmentParams(rect, isVertical);

    switch (_resolvedDirection) {
      case TooltipDirection.top:
        return Positioned(
          bottom: screenSize.height - rect.top + offset,
          left: anchorPoint,
          child: FractionalTranslation(
            translation: Offset(fracTranslation, 0),
            child: tooltipChild,
          ),
        );
      case TooltipDirection.bottom:
        return Positioned(
          top: rect.bottom + offset,
          left: anchorPoint,
          child: FractionalTranslation(
            translation: Offset(fracTranslation, 0),
            child: tooltipChild,
          ),
        );
      case TooltipDirection.left:
        return Positioned(
          right: screenSize.width - rect.left + offset,
          top: anchorPoint,
          child: FractionalTranslation(
            translation: Offset(0, fracTranslation),
            child: tooltipChild,
          ),
        );
      case TooltipDirection.right:
        return Positioned(
          left: rect.right + offset,
          top: anchorPoint,
          child: FractionalTranslation(
            translation: Offset(0, fracTranslation),
            child: tooltipChild,
          ),
        );
    }
  }

  (double, double) _getAlignmentParams(Rect rect, bool isVertical) {
    return switch (_effectiveAlignment) {
      TooltipAlignment.start => (isVertical ? rect.left : rect.top, 0.0),
      TooltipAlignment.center => (isVertical ? rect.center.dx : rect.center.dy, -0.5),
      TooltipAlignment.end => (isVertical ? rect.right : rect.bottom, -1.0),
    };
  }

  Widget _buildTooltipWithArrow(BuildContext context) {
    final frameUi = widget.content.variables.frameUI;
    final container = frameUi?.container;
    final backgroundColor = container?.style?.backgroundColor ?? const Color(0xFF333333);
    final arrowColor = _effectiveArrowColor ?? backgroundColor;
    final outlineColor = container?.style?.outlineColor;

    final arrowDirection = switch (_resolvedDirection) {
      TooltipDirection.bottom => TooltipDirection.top,
      TooltipDirection.top => TooltipDirection.bottom,
      TooltipDirection.left => TooltipDirection.right,
      TooltipDirection.right => TooltipDirection.left,
    };

    final arrowWidget = _buildArrow(arrowDirection, arrowColor, outlineColor: outlineColor);
    final bodyWidget = _buildTooltipBody(backgroundColor);

    final arrowHeight = _effectiveArrowHeight;
    final arrowWidth = _effectiveArrowWidth;

    final arrowPositioned = _getArrowPositioned(
      arrowWidget: arrowWidget,
      arrowWidth: arrowWidth,
      arrowHeight: arrowHeight,
    );

    final bodyPadding = switch (_resolvedDirection) {
      TooltipDirection.top => EdgeInsets.only(bottom: arrowHeight - 1),
      TooltipDirection.bottom => EdgeInsets.only(top: arrowHeight - 1),
      TooltipDirection.left => EdgeInsets.only(right: arrowHeight - 1),
      TooltipDirection.right => EdgeInsets.only(left: arrowHeight - 1),
    };

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: bodyPadding, child: bodyWidget),
          arrowPositioned,
        ],
      ),
    );
  }

  Positioned _getArrowPositioned({
    required Widget arrowWidget,
    required double arrowWidth,
    required double arrowHeight,
  }) {
    final arrowAlignment = _effectiveArrowAlignment;
    final cornerRadius = widget.content.variables.frameUI?.container.style?.cornerRadius ?? 8.0;
    final edgeInset = cornerRadius + arrowWidth / 2;

    return switch (_resolvedDirection) {
      TooltipDirection.bottom => Positioned(
        top: 0,
        left: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.start ? edgeInset : null),
        right: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.end ? edgeInset : null),
        child: arrowAlignment == ArrowAlignment.center ? Center(child: arrowWidget) : arrowWidget,
      ),
      TooltipDirection.top => Positioned(
        bottom: 0,
        left: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.start ? edgeInset : null),
        right: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.end ? edgeInset : null),
        child: arrowAlignment == ArrowAlignment.center ? Center(child: arrowWidget) : arrowWidget,
      ),
      TooltipDirection.right => Positioned(
        left: 0,
        top: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.start ? edgeInset : null),
        bottom: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.end ? edgeInset : null),
        child: arrowAlignment == ArrowAlignment.center ? Center(child: arrowWidget) : arrowWidget,
      ),
      TooltipDirection.left => Positioned(
        right: 0,
        top: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.start ? edgeInset : null),
        bottom: arrowAlignment == ArrowAlignment.center ? 0 : (arrowAlignment == ArrowAlignment.end ? edgeInset : null),
        child: arrowAlignment == ArrowAlignment.center ? Center(child: arrowWidget) : arrowWidget,
      ),
    };
  }

  Widget _buildArrow(TooltipDirection direction, Color color, {Color? outlineColor}) {
    final isVertical = direction == TooltipDirection.top || direction == TooltipDirection.bottom;
    final width = isVertical ? _effectiveArrowWidth : _effectiveArrowHeight;
    final height = isVertical ? _effectiveArrowHeight : _effectiveArrowWidth;

    return CustomPaint(
      size: Size(width, height),
      painter: TooltipArrowPainter(
        direction: direction,
        color: color,
        outlineColor: outlineColor,
      ),
    );
  }

  Widget _buildTooltipBody(Color backgroundColor) {
    final frameUi = widget.content.variables.frameUI;
    final container = frameUi?.container;
    final elements = widget.content.variables.elements;
    final products = widget.content.products;
    final cornerRadius = container?.style?.cornerRadius ?? 8.0;
    final outlineColor = container?.style?.outlineColor;

    return Container(
      constraints: BoxConstraints(maxWidth: widget.config.effectiveMaxWidth),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: outlineColor != null ? Border.all(color: outlineColor, width: 1) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.only(
        left: container?.style?.padding?.left ?? 12,
        top: container?.style?.padding?.top ?? 10,
        right: container?.style?.padding?.right ?? 12,
        bottom: container?.style?.padding?.bottom ?? 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            elements
                ?.map(
                  (e) => GravityElement(
                    element: e,
                    campaign: widget.campaign,
                    content: widget.content,
                    products: products,
                    onClickCallback: (action) {
                      onClickHandler.handeOnClick(action, context);
                      if (action.closeOnClick == true && action.action != Action.openStep) {
                        widget.onDismiss();
                      }
                    },
                  ).getWidget(),
                )
                .toList() ??
            [],
      ),
    );
  }
}
