import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';

import 'package:flutter/material.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';

class const RollingDailyGoal({
  required final double value,
  required final String label,
  required final Color color,
}) {
  /// Legend text reframing the trailing-window goal as an average daily pace.
  String legendWithDailyPace({int rollingDays = 7}) {
    final minutesPerDay = (value / rollingDays).round();
    return '$label · ${minutesPerDay}m/day';
  }
}

class RollingDailyPainter({
  required final List<RollingDailyPoint> points,
  required final List<RollingDailyGoal> goals,
  required final Color lineColor,
  required final String Function(double value) formatValue,
  final DateTime? displayStart,
  final DateTime? displayEnd,
  final RollingDailyPoint? inspectedPoint,
  final bool clockMinuteAxis = false,
}) extends CustomPainter {
  static const leftPadding = 36.0;
  static const rightPadding = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final visiblePoints = _visiblePoints();
    if (visiblePoints.length < 2) return;

    final plot = _plotAcrossVisibleDates(size, visiblePoints);
    _paintDateGridAndYearBoundaries(canvas, plot);
    _strokeTrailingWindowGoals(canvas, plot);
    _strokeSmoothedTrailingSevenDayTotal(canvas, plot, visiblePoints);
    _paintDayDotsWhenUnderNinetyPoints(canvas, plot, visiblePoints);
    _paintInspectedDay(canvas, plot);
    _paintNiceValueTicks(canvas, plot);
  }

  EChartPlot _plotAcrossVisibleDates(
    Size size,
    List<RollingDailyPoint> visiblePoints,
  ) {
    return EChartPlot(
      size: size,
      leftPadding: leftPadding,
      rightPadding: rightPadding,
      topPadding: 8,
      bottomPadding: 24,
      start: displayStart ?? visiblePoints.first.date,
      end: displayEnd ?? visiblePoints.last.date,
      valueScale: _niceValueScale(visiblePoints),
    );
  }

  EChartValueScale _niceValueScale(List<RollingDailyPoint> visiblePoints) {
    final double peak = [
      ...visiblePoints.map((point) => point.smoothedValue),
      ...goals.map((goal) => goal.value),
    ].max;
    if (clockMinuteAxis) return EChartValueScale.clockMinutes(peak);
    return EChartValueScale.nice(peak, targetTickCount: 4);
  }

  void _paintDateGridAndYearBoundaries(Canvas canvas, EChartPlot plot) {
    _strokeNiceTickGuides(canvas, plot);
    final chrome = EChartChrome(plot);
    chrome.strokePlotEdges(canvas);
    chrome.paintYearBoundaryGuides(canvas);
    chrome.paintDateTicks(canvas);
  }

  void _strokeNiceTickGuides(Canvas canvas, EChartPlot plot) {
    final gridPaint = Paint()
      ..color = EColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    for (final tick in plot.valueScale.ticks) {
      if (tick <= plot.valueScale.min || tick >= plot.valueScale.max) continue;
      final lineY = plot.yForValue(tick);
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(plot.right, lineY),
        gridPaint,
      );
    }
  }

  void _strokeTrailingWindowGoals(Canvas canvas, EChartPlot plot) {
    for (final goal in goals) {
      final goalY = plot.yForValue(goal.value);
      final goalPaint = Paint()
        ..color = goal.color.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(plot.left, goalY),
        Offset(plot.right, goalY),
        goalPaint,
      );
      _paintTrailingWindowGoalLabel(
        canvas,
        goal,
        Offset(plot.right - 2, goalY - 12),
      );
    }
  }

  void _paintTrailingWindowGoalLabel(
    Canvas canvas,
    RollingDailyGoal goal,
    Offset position,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: goal.label,
        style: TextStyle(
          color: goal.color.withValues(alpha: 0.7),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width, position.dy),
    );
  }

  void _strokeSmoothedTrailingSevenDayTotal(
    Canvas canvas,
    EChartPlot plot,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final loadPath = Path();
    for (var pointIndex = 0; pointIndex < visiblePoints.length; pointIndex++) {
      final point = visiblePoints[pointIndex];
      final pointOffset = Offset(
        plot.xForDate(point.date),
        plot.yForValue(point.smoothedValue),
      );
      if (pointIndex == 0) {
        loadPath.moveTo(pointOffset.dx, pointOffset.dy);
      } else {
        loadPath.lineTo(pointOffset.dx, pointOffset.dy);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(loadPath, linePaint);
  }

  void _paintDayDotsWhenUnderNinetyPoints(
    Canvas canvas,
    EChartPlot plot,
    List<RollingDailyPoint> visiblePoints,
  ) {
    if (visiblePoints.length > 90) return;

    final pointPaint = Paint()..color = lineColor;
    for (final point in visiblePoints) {
      canvas.drawCircle(
        Offset(plot.xForDate(point.date), plot.yForValue(point.smoothedValue)),
        2,
        pointPaint,
      );
    }
  }

  void _paintInspectedDay(Canvas canvas, EChartPlot plot) {
    final inspected = inspectedPoint;
    if (inspected == null) return;

    final hoveredX = plot.xForDate(inspected.date);
    final hoveredY = plot.yForValue(inspected.smoothedValue);
    final markerPaint = Paint()
      ..color = EColors.textTertiary.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final ringPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(hoveredX, plot.top),
      Offset(hoveredX, plot.bottom),
      markerPaint,
    );
    canvas.drawCircle(Offset(hoveredX, hoveredY), 5, ringPaint);
  }

  void _paintNiceValueTicks(Canvas canvas, EChartPlot plot) {
    for (final tick in plot.valueScale.ticks) {
      final textPainter = TextPainter(
        text: TextSpan(text: formatValue(tick), style: EChartAxis.tickLabel),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: plot.left - 4);
      final tickY = (plot.yForValue(tick) - textPainter.height / 2).clamp(
        plot.top,
        plot.bottom - textPainter.height,
      );
      textPainter.paint(
        canvas,
        Offset(plot.left - textPainter.width - 4, tickY),
      );
    }
  }

  List<RollingDailyPoint> _visiblePoints() {
    return points.where((point) {
      if (displayStart != null && point.date.isBefore(displayStart!)) {
        return false;
      }
      if (displayEnd != null && point.date.isAfter(displayEnd!)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  bool shouldRepaint(covariant RollingDailyPainter oldDelegate) =>
      points != oldDelegate.points ||
      goals != oldDelegate.goals ||
      lineColor != oldDelegate.lineColor ||
      displayStart != oldDelegate.displayStart ||
      displayEnd != oldDelegate.displayEnd ||
      inspectedPoint?.date != oldDelegate.inspectedPoint?.date ||
      inspectedPoint?.smoothedValue !=
          oldDelegate.inspectedPoint?.smoothedValue ||
      clockMinuteAxis != oldDelegate.clockMinuteAxis;
}
