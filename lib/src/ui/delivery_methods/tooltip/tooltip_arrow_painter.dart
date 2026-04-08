import 'package:flutter/material.dart';
import '../../../models/internal/tooltip_positioning.dart';

class TooltipArrowPainter extends CustomPainter {
  final TooltipDirection direction;
  final Color color;
  final Color? outlineColor;
  final double strokeWidth;

  TooltipArrowPainter({
    required this.direction,
    required this.color,
    this.outlineColor,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _buildArrowPath(size);
    canvas.drawPath(path, fillPaint);

    if (outlineColor != null) {
      final strokePaint = Paint()
        ..color = outlineColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final strokePath = _buildArrowStrokePath(size);
      canvas.drawPath(strokePath, strokePaint);
    }
  }

  Path _buildArrowPath(Size size) {
    final path = Path();

    switch (direction) {
      case TooltipDirection.top:
        path.moveTo(0, size.height);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
        path.close();
      case TooltipDirection.bottom:
        path.moveTo(0, 0);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(size.width, 0);
        path.close();
      case TooltipDirection.left:
        path.moveTo(size.width, 0);
        path.lineTo(0, size.height / 2);
        path.lineTo(size.width, size.height);
        path.close();
      case TooltipDirection.right:
        path.moveTo(0, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(0, size.height);
        path.close();
    }

    return path;
  }

  Path _buildArrowStrokePath(Size size) {
    final path = Path();

    switch (direction) {
      case TooltipDirection.top:
        path.moveTo(0, size.height);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
      case TooltipDirection.bottom:
        path.moveTo(0, 0);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(size.width, 0);
      case TooltipDirection.left:
        path.moveTo(size.width, 0);
        path.lineTo(0, size.height / 2);
        path.lineTo(size.width, size.height);
      case TooltipDirection.right:
        path.moveTo(0, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(0, size.height);
    }

    return path;
  }

  @override
  bool shouldRepaint(TooltipArrowPainter oldDelegate) {
    return direction != oldDelegate.direction ||
        color != oldDelegate.color ||
        outlineColor != oldDelegate.outlineColor ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
