import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/chart_date_axis.dart';
import 'package:workouts/widgets/trend_series.dart';

class ChartTooltip {
  ChartTooltip({
    required this.canvas,
    required this.layout,
    required this.hoverPosition,
    required this.visibleSeries,
  }) : _clampedX = hoverPosition.dx.clamp(layout.left, layout.right);

  final Canvas canvas;
  final ChartDateLayout layout;
  final Offset hoverPosition;
  final List<TrendSeries> visibleSeries;
  final double _clampedX;

  static const _fontSize = 10.0;
  static const _lineHeight = 14.0;
  static const _paddingH = 8.0;
  static const _paddingV = 6.0;

  void paint() {
    _drawCrosshairLine();
    final lines = _buildLines();
    _drawTooltipBox(lines);
  }

  void _drawCrosshairLine() {
    final linePaint = Paint()
      ..color = AppColors.textColor3.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(_clampedX, layout.top),
      Offset(_clampedX, layout.bottom),
      linePaint,
    );
  }

  List<_TooltipLine> _buildLines() {
    final hoverDate = layout.dateForX(_clampedX);
    final secondsFromOrigin =
        hoverDate.difference(layout.minDate).inSeconds.toDouble();

    final lines = <_TooltipLine>[
      _TooltipLine(text: _formatDate(hoverDate), color: AppColors.textColor3),
    ];

    for (final series in visibleSeries) {
      if (series.points.length < 2) continue;
      final trend = computeTrendLine(series.points, layout.minDate);
      final yHat = trend.intercept + trend.slope * secondsFromOrigin;
      lines.add(_TooltipLine(
        text: '${series.label}: ${series.formatValue(yHat.abs())}',
        color: series.color,
      ));
    }

    return lines;
  }

  void _drawTooltipBox(List<_TooltipLine> lines) {
    final painters = _layoutText(lines);
    final boxRect = _computeRect(painters, lines.length);
    _drawBackground(boxRect);
    _drawText(boxRect, painters);
  }

  List<TextPainter> _layoutText(List<_TooltipLine> lines) {
    return lines.map((line) {
      return TextPainter(
        text: TextSpan(
          text: line.text,
          style: TextStyle(color: line.color, fontSize: _fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }).toList();
  }

  RRect _computeRect(List<TextPainter> painters, int lineCount) {
    final maxTextWidth = painters.fold(0.0, (w, p) => math.max(w, p.width));
    final boxWidth = maxTextWidth + _paddingH * 2;
    final boxHeight = _lineHeight * lineCount + _paddingV * 2;

    final anchorRight = _clampedX + boxWidth + 12 > layout.right;
    final boxLeft = anchorRight ? _clampedX - boxWidth - 8 : _clampedX + 8;

    return RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, layout.top, boxWidth, boxHeight),
      const Radius.circular(6),
    );
  }

  void _drawBackground(RRect rect) {
    canvas.drawRRect(
      rect,
      Paint()..color = AppColors.backgroundDepth2.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.borderDepth1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawText(RRect rect, List<TextPainter> painters) {
    for (var i = 0; i < painters.length; i++) {
      painters[i].paint(
        canvas,
        Offset(
          rect.left + _paddingH,
          rect.top + _paddingV + i * _lineHeight,
        ),
      );
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _TooltipLine {
  const _TooltipLine({required this.text, required this.color});

  final String text;
  final Color color;
}
