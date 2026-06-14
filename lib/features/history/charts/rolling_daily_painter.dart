import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/chart_date_axis.dart';

class RollingDailyGoal {
  const RollingDailyGoal({
    required this.value,
    required this.label,
    required this.color,
  });

  final double value;
  final String label;
  final Color color;
}

class RollingDailyPainter extends CustomPainter {
  RollingDailyPainter({
    required this.points,
    required this.goals,
    required this.lineColor,
    required this.formatValue,
    this.displayStart,
    this.displayEnd,
    this.hoverPosition,
  });

  static const leftPadding = 36.0;
  static const rightPadding = 12.0;

  final List<RollingDailyPoint> points;
  final List<RollingDailyGoal> goals;
  final Color lineColor;
  final String Function(double value) formatValue;
  final DateTime? displayStart;
  final DateTime? displayEnd;
  final Offset? hoverPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final visiblePoints = _visiblePoints();
    if (visiblePoints.length < 2) return;

    final layout = _layout(size, visiblePoints);
    final scale = _valueScale(visiblePoints);
    _drawBackground(canvas, layout);
    _drawGoalLines(canvas, layout, scale);
    _drawSeriesLine(canvas, layout, scale, visiblePoints);
    _drawSeriesPoints(canvas, layout, scale, visiblePoints);
    _drawHoverMarker(canvas, layout, scale, visiblePoints);
    _drawAxisLabels(canvas, layout, scale);
  }

  ChartDateLayout _layout(Size size, List<RollingDailyPoint> visiblePoints) {
    return ChartDateLayout(
      size: size,
      leftPadding: leftPadding,
      rightPadding: rightPadding,
      topPadding: 8,
      bottomPadding: 24,
      minDate: displayStart ?? visiblePoints.first.date,
      maxDate: displayEnd ?? visiblePoints.last.date,
    );
  }

  RollingDailyScale _valueScale(List<RollingDailyPoint> visiblePoints) {
    final highestSeriesValue = visiblePoints.fold(
      0.0,
      (highest, point) => math.max(highest, point.smoothedValue),
    );
    final highestGoalValue = goals.fold(
      0.0,
      (highest, goal) => math.max(highest, goal.value),
    );
    final maxValue = math.max(highestSeriesValue, highestGoalValue);
    return RollingDailyScale(maxValue: math.max(1, maxValue * 1.12));
  }

  void _drawBackground(Canvas canvas, ChartDateLayout layout) {
    _drawHorizontalGrid(canvas, layout);
    layout.drawAxes(canvas);
    layout.drawYearBoundaries(canvas);
    layout.drawDateLabels(canvas, labelColor: AppColors.textColor4);
  }

  void _drawHorizontalGrid(Canvas canvas, ChartDateLayout layout) {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    const lineCount = 4;
    for (var lineIndex = 0; lineIndex <= lineCount; lineIndex++) {
      final lineFraction = lineIndex / lineCount;
      final lineY = layout.top + lineFraction * layout.height;
      canvas.drawLine(
        Offset(layout.left, lineY),
        Offset(layout.right, lineY),
        gridPaint,
      );
    }
  }

  void _drawGoalLines(
    Canvas canvas,
    ChartDateLayout layout,
    RollingDailyScale scale,
  ) {
    for (final goal in goals) {
      final goalY = scale.yForValue(goal.value, layout);
      final goalPaint = Paint()
        ..color = goal.color.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(layout.left, goalY),
        Offset(layout.right, goalY),
        goalPaint,
      );
      _drawGoalLabel(canvas, goal, Offset(layout.right - 2, goalY - 12));
    }
  }

  void _drawGoalLabel(Canvas canvas, RollingDailyGoal goal, Offset position) {
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

  void _drawSeriesLine(
    Canvas canvas,
    ChartDateLayout layout,
    RollingDailyScale scale,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final seriesPath = Path();
    for (var pointIndex = 0; pointIndex < visiblePoints.length; pointIndex++) {
      final point = visiblePoints[pointIndex];
      final pointOffset = Offset(
        layout.xForDate(point.date),
        scale.yForValue(point.smoothedValue, layout),
      );
      if (pointIndex == 0) {
        seriesPath.moveTo(pointOffset.dx, pointOffset.dy);
      } else {
        seriesPath.lineTo(pointOffset.dx, pointOffset.dy);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(seriesPath, linePaint);
  }

  void _drawSeriesPoints(
    Canvas canvas,
    ChartDateLayout layout,
    RollingDailyScale scale,
    List<RollingDailyPoint> visiblePoints,
  ) {
    if (visiblePoints.length > 90) return;

    final pointPaint = Paint()..color = lineColor;
    for (final point in visiblePoints) {
      canvas.drawCircle(
        Offset(
          layout.xForDate(point.date),
          scale.yForValue(point.smoothedValue, layout),
        ),
        2,
        pointPaint,
      );
    }
  }

  void _drawHoverMarker(
    Canvas canvas,
    ChartDateLayout layout,
    RollingDailyScale scale,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final hoveredPoint = _pointNearestHover(layout, visiblePoints);
    if (hoveredPoint == null) return;

    final hoveredX = layout.xForDate(hoveredPoint.date);
    final hoveredY = scale.yForValue(hoveredPoint.smoothedValue, layout);
    final markerPaint = Paint()
      ..color = AppColors.textColor3.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final ringPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(hoveredX, layout.top),
      Offset(hoveredX, layout.bottom),
      markerPaint,
    );
    canvas.drawCircle(Offset(hoveredX, hoveredY), 5, ringPaint);
  }

  void _drawAxisLabels(
    Canvas canvas,
    ChartDateLayout layout,
    RollingDailyScale scale,
  ) {
    _drawAxisLabel(canvas, formatValue(scale.maxValue), Offset(2, layout.top));
    _drawAxisLabel(canvas, formatValue(0), Offset(10, layout.bottom - 10));
  }

  void _drawAxisLabel(Canvas canvas, String text, Offset position) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.textColor4, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }

  RollingDailyPoint? _pointNearestHover(
    ChartDateLayout layout,
    List<RollingDailyPoint> visiblePoints,
  ) {
    final position = hoverPosition;
    if (position == null || visiblePoints.isEmpty) return null;

    final hoverDate = layout.dateForX(position.dx);
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

class RollingDailyScale {
  const RollingDailyScale({required this.maxValue});

  final double maxValue;

  double yForValue(double value, ChartDateLayout layout) {
    final valueFraction = (value / maxValue).clamp(0.0, 1.0);
    return layout.bottom - valueFraction * layout.height;
  }
}
