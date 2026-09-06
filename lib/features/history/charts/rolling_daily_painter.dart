import 'dart:math' as math;
import 'package:ethan_ui/ethan_ui.dart';

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
  final Offset? hoverPosition,
}) extends CustomPainter {
  static const leftPadding = 36.0;
  static const rightPadding = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final visiblePoints = _visiblePoints();
    if (visiblePoints.length < 2) return;

    final plot = _plotAcrossVisibleDates(size, visiblePoints);
    final scale = _valueScale(visiblePoints);
    _paintDateGridAndYearBoundaries(canvas, plot);
    _strokeTrailingWindowGoals(canvas, plot, scale);
    _strokeSmoothedTrailingSevenDayTotal(canvas, plot, scale, visiblePoints);
    _paintDayDotsWhenUnderNinetyPoints(canvas, plot, scale, visiblePoints);
    _paintScrubCrosshairOnNearestDay(canvas, plot, scale, visiblePoints);
    _paintZeroAndMaxLoad(canvas, plot, scale);
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
      valueScale: EChartValueScale.fixed(
        min: 0,
        max: 1,
        ticks: const [0, 1],
      ),
    );
  }

  RollingDailyScale _valueScale(List<RollingDailyPoint> visiblePoints) {
    final highestSmoothedValue = visiblePoints.fold(
      0.0,
      (highest, point) => math.max(highest, point.smoothedValue),
    );
    final highestGoalValue = goals.fold(
      0.0,
      (highest, goal) => math.max(highest, goal.value),
    );
    final maxValue = math.max(highestSmoothedValue, highestGoalValue);
    return RollingDailyScale(maxValue: math.max(1, maxValue * 1.12));
  }

  void _paintDateGridAndYearBoundaries(Canvas canvas, EChartPlot plot) {
    _strokeQuarterHeightGuides(canvas, plot);
    final chrome = EChartChrome(plot);
    chrome.strokePlotEdges(canvas);
    chrome.paintYearBoundaryGuides(canvas);
    chrome.paintDateTicks(canvas);
  }

  void _strokeQuarterHeightGuides(Canvas canvas, EChartPlot plot) {
    final gridPaint = Paint()
      ..color = EColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    const lineCount = 4;
    for (var lineIndex = 0; lineIndex <= lineCount; lineIndex++) {
      final lineFraction = lineIndex / lineCount;
      final lineY = plot.top + lineFraction * plot.height;
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(plot.right, lineY),
        gridPaint,
      );
    }
  }

  void _strokeTrailingWindowGoals(
    Canvas canvas,
    EChartPlot plot,
    RollingDailyScale scale,
  ) {
    for (final goal in goals) {
      final goalY = scale.yForValue(goal.value, plot);
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
    RollingDailyScale scale,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final loadPath = Path();
    for (var pointIndex = 0; pointIndex < visiblePoints.length; pointIndex++) {
      final point = visiblePoints[pointIndex];
      final pointOffset = Offset(
        plot.xForDate(point.date),
        scale.yForValue(point.smoothedValue, plot),
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
    RollingDailyScale scale,
    List<RollingDailyPoint> visiblePoints,
  ) {
    if (visiblePoints.length > 90) return;

    final pointPaint = Paint()..color = lineColor;
    for (final point in visiblePoints) {
      canvas.drawCircle(
        Offset(
          plot.xForDate(point.date),
          scale.yForValue(point.smoothedValue, plot),
        ),
        2,
        pointPaint,
      );
    }
  }

  void _paintScrubCrosshairOnNearestDay(
    Canvas canvas,
    EChartPlot plot,
    RollingDailyScale scale,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final hoveredPoint = _pointNearestHover(plot, visiblePoints);
    if (hoveredPoint == null) return;

    final hoveredX = plot.xForDate(hoveredPoint.date);
    final hoveredY = scale.yForValue(hoveredPoint.smoothedValue, plot);
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

  void _paintZeroAndMaxLoad(
    Canvas canvas,
    EChartPlot plot,
    RollingDailyScale scale,
  ) {
    _paintLoadLabel(canvas, formatValue(scale.maxValue), Offset(2, plot.top));
    _paintLoadLabel(canvas, formatValue(0), Offset(10, plot.bottom - 10));
  }

  void _paintLoadLabel(Canvas canvas, String text, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: EColors.textMuted, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }

  RollingDailyPoint? _pointNearestHover(
    EChartPlot plot,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final position = hoverPosition;
    if (position == null || visiblePoints.isEmpty) return null;

    final hoverDate = plot.dateForX(position.dx);
    return visiblePoints.reduce(
      (nearestPoint, point) =>
          _dateDistance(point, hoverDate) <
              _dateDistance(nearestPoint, hoverDate)
          ? point
          : nearestPoint,
    );
  }

  int _dateDistance(RollingDailyPoint point, DateTime date) =>
      point.date.difference(date).inSeconds.abs();

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
      hoverPosition != oldDelegate.hoverPosition;
}

class const RollingDailyScale({required final double maxValue}) {
  double yForValue(double value, EChartPlot plot) {
    final valueFraction = (value / maxValue).clamp(0.0, 1.0);
    return plot.bottom - valueFraction * plot.height;
  }
}
