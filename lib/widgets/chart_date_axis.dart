import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:workouts/theme/app_theme.dart';

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
}

const _months = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

List<DateTime> chartDateTicks(ChartDateLayout layout) {
  final spanDays = layout.maxDate.difference(layout.minDate).inDays;
  if (spanDays <= 0) return [layout.minDate];

  final targetCount = math.max(3, (layout.width / 70).round());

  if (spanDays > 90) {
    final monthStep = math.max(1, (spanDays / 30 / targetCount).ceil());
    final ticks = <DateTime>[];
    var cursor = DateTime(layout.minDate.year, layout.minDate.month + monthStep);
    while (cursor.isBefore(layout.maxDate)) {
      ticks.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + monthStep);
    }
    return [layout.minDate, ...ticks, layout.maxDate];
  }

  final stepDays = math.max(1, (spanDays / targetCount).round());
  final ticks = <DateTime>[layout.minDate];
  final minDate = layout.minDate;
  var cursor = DateTime(minDate.year, minDate.month, minDate.day + stepDays);
  final minGap = stepDays ~/ 2;
  final maxDate = layout.maxDate;
  while (cursor.isBefore(
      DateTime(maxDate.year, maxDate.month, maxDate.day - minGap))) {
    ticks.add(cursor);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + stepDays);
  }
  ticks.add(layout.maxDate);
  return ticks;
}

void drawChartDateLabels(
  Canvas canvas,
  ChartDateLayout layout, {
  Color? labelColor,
}) {
  final spanDays = layout.maxDate.difference(layout.minDate).inDays;
  final color = labelColor ?? AppColors.textColor4;

  String formatLabel(DateTime date) {
    if (spanDays > 60) return _months[date.month];
    return '${date.month}/${date.day}';
  }

  for (final date in chartDateTicks(layout)) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: formatLabel(date),
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final x = (layout.xForDate(date) - textPainter.width / 2)
        .clamp(layout.left - 4, layout.right - textPainter.width + 4);
    textPainter.paint(canvas, Offset(x, layout.bottom + 6));
  }
}

void drawChartYearBoundaries(Canvas canvas, ChartDateLayout layout) {
  if (layout.minDate.year == layout.maxDate.year) return;

  final linePaint = Paint()
    ..color = AppColors.textColor4.withValues(alpha: 0.3)
    ..strokeWidth = 1;

  for (var year = layout.minDate.year + 1;
      year <= layout.maxDate.year;
      year++) {
    final DateTime jan1 = DateTime(year);
    final double x = layout.xForDate(jan1);
    canvas.drawLine(
      Offset(x, layout.top),
      Offset(x, layout.bottom),
      linePaint,
    );

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
    textPainter.paint(canvas, Offset(x + 4, layout.top + 2));
  }
}
