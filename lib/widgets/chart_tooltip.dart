import 'dart:math' as math;
import 'package:ethan_ui/ethan_ui.dart';

import 'package:flutter/material.dart';
import 'package:workouts/widgets/chart_date_plot.dart';
import 'package:workouts/widgets/metric_trend.dart';

class ChartTooltip({
  required final Canvas canvas,
  required final ChartDatePlot plot,
  required final Offset hoverPosition,
  required final List<MetricTrend> visibleTrends,
}) {
  final double _clampedX = hoverPosition.dx.clamp(plot.left, plot.right);

  static const _fontSize = 10.0;
  static const _lineHeight = 14.0;
  static const _paddingH = 8.0;
  static const _paddingV = 6.0;

  void paint() {
    _strokeHoverDateCrosshair();
    final lines = _leastSquaresValuesAtHoverDate();
    _paintHoverReadout(lines);
  }

  void _strokeHoverDateCrosshair() {
    final linePaint = Paint()
      ..color = EColors.textTertiary.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(_clampedX, plot.top),
      Offset(_clampedX, plot.bottom),
      linePaint,
    );
  }

  List<_TooltipLine> _leastSquaresValuesAtHoverDate() {
    final hoverDate = plot.dateForX(_clampedX);
    final secondsFromOrigin = hoverDate
        .difference(plot.minDate)
        .inSeconds
        .toDouble();

    final lines = <_TooltipLine>[
      _TooltipLine(text: _formatDate(hoverDate), color: EColors.textTertiary),
    ];

    for (final metricTrend in visibleTrends) {
      if (metricTrend.points.length < 2) continue;
      final trend = leastSquaresTrend(metricTrend.points, plot.minDate);
      final yHat = trend.intercept + trend.slope * secondsFromOrigin;
      lines.add(
        _TooltipLine(
          text: '${metricTrend.label}: ${metricTrend.formatValue(yHat.abs())}',
          color: metricTrend.color,
        ),
      );
    }

    return lines;
  }

  void _paintHoverReadout(List<_TooltipLine> lines) {
    final painters = _measureReadoutLines(lines);
    final boxRect = _readoutCardAvoidingRightEdge(painters, lines.length);
    _paintReadoutCard(boxRect);
    _paintReadoutLines(boxRect, painters);
  }

  List<TextPainter> _measureReadoutLines(List<_TooltipLine> lines) {
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

  RRect _readoutCardAvoidingRightEdge(
    List<TextPainter> painters,
    int lineCount,
  ) {
    final maxTextWidth = painters.fold(0.0, (w, p) => math.max(w, p.width));
    final boxWidth = maxTextWidth + _paddingH * 2;
    final boxHeight = _lineHeight * lineCount + _paddingV * 2;

    final anchorRight = _clampedX + boxWidth + 12 > plot.right;
    final boxLeft = anchorRight ? _clampedX - boxWidth - 8 : _clampedX + 8;

    return RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, plot.top, boxWidth, boxHeight),
      const Radius.circular(6),
    );
  }

  void _paintReadoutCard(RRect rect) {
    canvas.drawRRect(
      rect,
      Paint()..color = EColors.backgroundLift.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = EColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _paintReadoutLines(RRect rect, List<TextPainter> painters) {
    for (var lineIndex = 0; lineIndex < painters.length; lineIndex++) {
      painters[lineIndex].paint(
        canvas,
        Offset(
          rect.left + _paddingH,
          rect.top + _paddingV + lineIndex * _lineHeight,
        ),
      );
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class const _TooltipLine({
  required final String text,
  required final Color color,
});
