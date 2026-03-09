import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:workouts/theme/app_theme.dart';

const _months = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class ChartDateLayout {
  ChartDateLayout({
    required Size size,
    required double leftPadding,
    required double rightPadding,
    required double topPadding,
    required double bottomPadding,
    required this.minDate,
    required this.maxDate,
  }) {
    left = leftPadding;
    right = size.width - rightPadding;
    top = topPadding;
    bottom = size.height - bottomPadding;
    width = right - left;
    height = bottom - top;
    _dateRangeSeconds = maxDate.difference(minDate).inSeconds.toDouble();
  }

  final DateTime minDate;
  final DateTime maxDate;
  late final double left, right, top, bottom, width, height;
  late final double _dateRangeSeconds;

  double xForDate(DateTime date) {
    if (_dateRangeSeconds == 0) return left + width / 2;
    return left +
        (date.difference(minDate).inSeconds / _dateRangeSeconds) * width;
  }

  DateTime dateForX(double x) {
    if (width == 0) return minDate;
    final fraction = ((x - left) / width).clamp(0.0, 1.0);
    final seconds = (fraction * _dateRangeSeconds).round();
    return minDate.add(Duration(seconds: seconds));
  }

  List<DateTime> dateTicks() {
    final spanDays = maxDate.difference(minDate).inDays;
    if (spanDays <= 0) return [minDate];

    final targetCount = math.max(3, (width / 70).round());

    if (spanDays > 90) {
      final monthStep = math.max(1, (spanDays / 30 / targetCount).ceil());
      final ticks = <DateTime>[];
      var cursor = DateTime(minDate.year, minDate.month + monthStep);
      while (cursor.isBefore(maxDate)) {
        ticks.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + monthStep);
      }
      return [minDate, ...ticks, maxDate];
    }

    final stepDays = math.max(1, (spanDays / targetCount).round());
    final ticks = <DateTime>[minDate];
    var cursor = DateTime(minDate.year, minDate.month, minDate.day + stepDays);
    final minGap = stepDays ~/ 2;
    while (cursor.isBefore(
        DateTime(maxDate.year, maxDate.month, maxDate.day - minGap))) {
      ticks.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + stepDays);
    }
    ticks.add(maxDate);
    return ticks;
  }

  void drawDateLabels(Canvas canvas, {Color? labelColor}) {
    final spanDays = maxDate.difference(minDate).inDays;
    final color = labelColor ?? AppColors.textColor4;

    String formatLabel(DateTime date) {
      if (spanDays > 60) return _months[date.month];
      return '${date.month}/${date.day}';
    }

    for (final date in dateTicks()) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: formatLabel(date),
          style: TextStyle(color: color, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = (xForDate(date) - textPainter.width / 2)
          .clamp(left - 4, right - textPainter.width + 4);
      textPainter.paint(canvas, Offset(x, bottom + 6));
    }
  }

  void drawAxes(Canvas canvas, {bool xAxis = true, bool yAxis = true}) {
    final axisPaint = Paint()
      ..color = AppColors.textColor4.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    if (xAxis) {
      canvas.drawLine(Offset(left, bottom), Offset(right, bottom), axisPaint);
    }
    if (yAxis) {
      canvas.drawLine(Offset(left, top), Offset(left, bottom), axisPaint);
    }
  }

  void drawYearBoundaries(Canvas canvas) {
    if (minDate.year == maxDate.year) return;

    final linePaint = Paint()
      ..color = AppColors.textColor4.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    for (var year = minDate.year + 1; year <= maxDate.year; year++) {
      final DateTime jan1 = DateTime(year);
      final double x = xForDate(jan1);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), linePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$year',
          style: TextStyle(
            color: AppColors.textColor4.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x + 4, top + 2));
    }
  }
}
