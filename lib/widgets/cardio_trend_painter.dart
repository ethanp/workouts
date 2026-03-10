import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/chart_date_axis.dart';
import 'package:workouts/widgets/chart_tooltip.dart';
import 'package:workouts/widgets/trend_series.dart';

class CardioTrendPainter extends CustomPainter {
  CardioTrendPainter({
    required this.visibleSeries,
    this.displayStart,
    this.displayEnd,
    this.hoverPosition,
  });

  final List<TrendSeries> visibleSeries;
  final DateTime? displayStart;
  final DateTime? displayEnd;
  final Offset? hoverPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _buildLayout(size);
    _drawBackground(canvas, layout);
    for (final series in visibleSeries) {
      if (series.points.length < 2) continue;
      _drawSeries(canvas, layout, series);
    }
    if (hoverPosition != null) {
      ChartTooltip(
        canvas: canvas,
        layout: layout,
        hoverPosition: hoverPosition!,
        visibleSeries: visibleSeries,
      ).paint();
    }
  }

  ChartDateLayout _buildLayout(Size size) {
    final allDates = visibleSeries
        .expand((s) => s.points)
        .map((p) => p.date);
    final fallbackStart = allDates.isEmpty
        ? DateTime.now()
        : allDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final fallbackEnd = allDates.isEmpty
        ? DateTime.now()
        : allDates.reduce((a, b) => a.isAfter(b) ? a : b);

    return ChartDateLayout(
      size: size,
      leftPadding: 12,
      rightPadding: 12,
      topPadding: 8,
      bottomPadding: 24,
      minDate: displayStart ?? fallbackStart,
      maxDate: displayEnd ?? fallbackEnd,
    );
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
    for (var i = 0; i <= lineCount; i++) {
      final fraction = i / lineCount;
      final y = layout.top + fraction * layout.height;
      canvas.drawLine(
        Offset(layout.left, y),
        Offset(layout.right, y),
        gridPaint,
      );
    }
  }

  void _drawSeries(
    Canvas canvas,
    ChartDateLayout layout,
    TrendSeries series,
  ) {
    final range = SeriesValueScale(
      series.points,
      invertY: series.invertY,
    );
    _drawSeriesDots(canvas, layout, series, range);
    _drawSeriesTrendLine(canvas, layout, series, range);
  }

  void _drawSeriesDots(
    Canvas canvas,
    ChartDateLayout layout,
    TrendSeries series,
    SeriesValueScale range,
  ) {
    final dotPaint = Paint()..color = series.color;
    final borderPaint = Paint()
      ..color = series.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final point in series.points) {
      final x = layout.xForDate(point.date);
      final normalized = range.normalize(point.value);
      final y = layout.bottom - normalized * layout.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
      canvas.drawCircle(Offset(x, y), 5, borderPaint);
    }
  }

  void _drawSeriesTrendLine(
    Canvas canvas,
    ChartDateLayout layout,
    TrendSeries series,
    SeriesValueScale range,
  ) {
    final trend = computeTrendLine(series.points, layout.minDate);
    final dateRangeSeconds =
        layout.maxDate.difference(layout.minDate).inSeconds.toDouble();

    final startValue = trend.intercept;
    final endValue = trend.intercept + trend.slope * dateRangeSeconds;

    final startY = layout.bottom - range.normalize(startValue) * layout.height;
    final endY = layout.bottom - range.normalize(endValue) * layout.height;

    final trendPaint = Paint()
      ..color = series.color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(layout.left, startY),
      Offset(layout.right, endY),
      trendPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CardioTrendPainter oldDelegate) =>
      visibleSeries != oldDelegate.visibleSeries ||
      displayStart != oldDelegate.displayStart ||
      displayEnd != oldDelegate.displayEnd ||
      hoverPosition != oldDelegate.hoverPosition;
}
