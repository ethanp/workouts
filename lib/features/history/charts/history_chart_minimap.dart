import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/features/history/charts/week_zone_data.dart';
import 'package:workouts/features/history/charts/weekly_bar_chart.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/widgets/metric_trend.dart';

class const HistoryChartDateAxis({
  required final DateTime start,
  required final DateTime end,
}) {
  double xAt(DateTime date, double width) {
    final spanDays = end.startOfDay.difference(start.startOfDay).inDays;
    if (spanDays <= 0 || width <= 0) return 0;
    return date.startOfDay.difference(start.startOfDay).inDays / spanDays * width;
  }

  Rect weekBar({
    required DateTime weekStart,
    required double width,
    required double top,
    required double bottom,
  }) {
    final left = xAt(weekStart, width);
    final right = xAt(weekStart.shiftedByDays(7), width);
    final barRight = right - left > 1.5 ? right - 0.5 : left + 1;
    return Rect.fromLTRB(left, top, barRight, bottom);
  }
}

class RollingDailyMinimapPainter({
  required final List<RollingDailyPoint> points,
  required final DateTime fullStart,
  required final DateTime fullEnd,
  required final Color lineColor,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;
    var peak = 0.0;
    for (final point in points) {
      if (point.smoothedValue > peak) peak = point.smoothedValue;
    }
    if (peak <= 0) return;

    final axis = HistoryChartDateAxis(start: fullStart, end: fullEnd);
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = axis.xAt(point.date, size.width);
      final y = _MinimapPlot.yForValue(point.smoothedValue, peak, size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, _MinimapPlot.stroke(lineColor));
  }

  @override
  bool shouldRepaint(covariant RollingDailyMinimapPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.fullStart != fullStart ||
        oldDelegate.fullEnd != fullEnd ||
        oldDelegate.points.length != points.length;
  }
}

class StackedZoneWeekMinimapPainter({
  required final List<WeekZoneData> weeks,
  required final DateTime fullStart,
  required final DateTime fullEnd,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty || size.width <= 0 || size.height <= 0) return;
    var peakSeconds = 0;
    for (final week in weeks) {
      if (week.zoneTime.total > peakSeconds) peakSeconds = week.zoneTime.total;
    }
    if (peakSeconds <= 0) return;

    final axis = HistoryChartDateAxis(start: fullStart, end: fullEnd);
    for (final week in weeks) {
      final totalSeconds = week.zoneTime.total;
      if (totalSeconds <= 0) continue;
      final barHeight = totalSeconds / peakSeconds * (size.height - 6);
      final bar = axis.weekBar(
        weekStart: week.weekStart,
        width: size.width,
        top: size.height - 3 - barHeight,
        bottom: size.height - 3,
      );
      var segmentTop = bar.bottom;
      final zoneSeconds = week.zoneTime.asList;
      for (var zoneIndex = 0; zoneIndex < zoneSeconds.length; zoneIndex++) {
        final segmentHeight = zoneSeconds[zoneIndex] / totalSeconds * bar.height;
        if (segmentHeight <= 0) continue;
        segmentTop -= segmentHeight;
        canvas.drawRect(
          Rect.fromLTRB(bar.left, segmentTop, bar.right, segmentTop + segmentHeight),
          Paint()..color = HrZonePalette.zoneColors[zoneIndex],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StackedZoneWeekMinimapPainter oldDelegate) {
    return oldDelegate.fullStart != fullStart ||
        oldDelegate.fullEnd != fullEnd ||
        oldDelegate.weeks.length != weeks.length;
  }
}

class WeeklyValueMinimapPainter({
  required final List<WeekData> weeks,
  required final DateTime fullStart,
  required final DateTime fullEnd,
  required final Color barColor,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty || size.width <= 0 || size.height <= 0) return;
    var peak = 0.0;
    for (final week in weeks) {
      if (week.value > peak) peak = week.value;
    }
    if (peak <= 0) return;

    final axis = HistoryChartDateAxis(start: fullStart, end: fullEnd);
    final barPaint = Paint()..color = barColor;
    for (final week in weeks) {
      if (week.value <= 0) continue;
      final barHeight = week.value / peak * (size.height - 6);
      canvas.drawRect(
        axis.weekBar(
          weekStart: week.weekStart,
          width: size.width,
          top: size.height - 3 - barHeight,
          bottom: size.height - 3,
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyValueMinimapPainter oldDelegate) {
    return oldDelegate.barColor != barColor ||
        oldDelegate.fullStart != fullStart ||
        oldDelegate.fullEnd != fullEnd ||
        oldDelegate.weeks.length != weeks.length;
  }
}

class MetricTrendMinimapPainter({
  required final List<MetricTrend> trends,
  required final DateTime fullStart,
  required final DateTime fullEnd,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final axis = HistoryChartDateAxis(start: fullStart, end: fullEnd);
    for (final trend in trends) {
      if (trend.points.length < 2) continue;
      final scale = PaddedMetricScale(
        trend.points,
        lowerIsBetter: trend.lowerIsBetter,
      );
      final path = Path();
      for (var index = 0; index < trend.points.length; index++) {
        final point = trend.points[index];
        final x = axis.xAt(point.date, size.width);
        final y = _MinimapPlot.yForValue(
          scale.normalize(point.value),
          1,
          size.height,
        );
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, _MinimapPlot.stroke(trend.color));
    }
  }

  @override
  bool shouldRepaint(covariant MetricTrendMinimapPainter oldDelegate) {
    return oldDelegate.fullStart != fullStart ||
        oldDelegate.fullEnd != fullEnd ||
        oldDelegate.trends.length != trends.length;
  }
}

abstract final class _MinimapPlot() {
  static double yForValue(double value, double peak, double height) {
    return height - 3 - (value / peak) * (height - 6);
  }

  static Paint stroke(Color color) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
  }
}
