import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/chart_date_plot.dart';
import 'package:workouts/widgets/chart_tooltip.dart';
import 'package:workouts/widgets/metric_trend.dart';

class MetricTrendPainter({
  required final List<MetricTrend> visibleTrends,
  final DateTime? displayStart,
  final DateTime? displayEnd,
  final Offset? hoverPosition,
  final DateTime? highlightDate,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotAcrossVisibleDates(size);
    _paintDateGridAndYearBoundaries(canvas, plot);
    for (final metricTrend in visibleTrends) {
      if (metricTrend.points.length < 2) continue;
      _paintDayDotsAndLeastSquaresTrend(canvas, plot, metricTrend);
    }
    _paintPerMetricMinMaxAtPlotCorners(canvas, plot);
    if (hoverPosition != null) {
      ChartTooltip(
        canvas: canvas,
        plot: plot,
        hoverPosition: hoverPosition!,
        visibleTrends: visibleTrends,
      ).paint();
    }
  }

  void _paintPerMetricMinMaxAtPlotCorners(
    Canvas canvas,
    ChartDatePlot plot,
  ) {
    const double rowHeight = 11;
    const double horizontalInset = 4;
    double topCursorY = plot.top + 2;
    double bottomCursorY = plot.bottom - 2 - rowHeight;
    for (final metricTrend in visibleTrends) {
      if (metricTrend.points.length < 2) continue;
      final values = metricTrend.points.map((point) => point.value);
      final hi = values.reduce(
        (largest, current) => current > largest ? current : largest,
      );
      final lo = values.reduce(
        (smallest, current) => current < smallest ? current : smallest,
      );
      final highLabel = metricTrend.lowerIsBetter ? lo : hi;
      final lowLabel = metricTrend.lowerIsBetter ? hi : lo;
      _paintMetricExtremeLabel(
        canvas: canvas,
        text: metricTrend.formatValue(highLabel),
        position: Offset(plot.left + horizontalInset, topCursorY),
        color: metricTrend.color,
      );
      _paintMetricExtremeLabel(
        canvas: canvas,
        text: metricTrend.formatValue(lowLabel),
        position: Offset(plot.left + horizontalInset, bottomCursorY),
        color: metricTrend.color,
      );
      topCursorY += rowHeight;
      bottomCursorY -= rowHeight;
    }
  }

  void _paintMetricExtremeLabel({
    required Canvas canvas,
    required String text,
    required Offset position,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }

  ChartDatePlot _plotAcrossVisibleDates(Size size) {
    final allDates = visibleTrends
        .expand((metricTrend) => metricTrend.points)
        .map((trendPoint) => trendPoint.date);
    final fallbackStart = allDates.isEmpty
        ? DateTime.now()
        : allDates.reduce(
            (earlierDate, laterDate) =>
                earlierDate.isBefore(laterDate) ? earlierDate : laterDate,
          );
    final fallbackEnd = allDates.isEmpty
        ? DateTime.now()
        : allDates.reduce(
            (earlierDate, laterDate) =>
                earlierDate.isAfter(laterDate) ? earlierDate : laterDate,
          );

    return ChartDatePlot(
      size: size,
      leftPadding: 12,
      rightPadding: 12,
      topPadding: 8,
      bottomPadding: 24,
      minDate: displayStart ?? fallbackStart,
      maxDate: displayEnd ?? fallbackEnd,
    );
  }

  void _paintDateGridAndYearBoundaries(Canvas canvas, ChartDatePlot plot) {
    _strokeQuarterHeightGuides(canvas, plot);
    plot.strokeLeftAndBottomEdges(canvas);
    plot.drawYearBoundaries(canvas);
    plot.paintMonthOrDayLabels(canvas, labelColor: AppColors.textColor4);
  }

  void _strokeQuarterHeightGuides(Canvas canvas, ChartDatePlot plot) {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    const lineCount = 4;
    for (var lineIndex = 0; lineIndex <= lineCount; lineIndex++) {
      final fraction = lineIndex / lineCount;
      final lineY = plot.top + fraction * plot.height;
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(plot.right, lineY),
        gridPaint,
      );
    }
  }

  void _paintDayDotsAndLeastSquaresTrend(
    Canvas canvas,
    ChartDatePlot plot,
    MetricTrend metricTrend,
  ) {
    final range = PaddedMetricScale(
      metricTrend.points,
      lowerIsBetter: metricTrend.lowerIsBetter,
    );

    final clipRect = Rect.fromLTRB(
      plot.left,
      plot.top,
      plot.right,
      plot.bottom,
    );
    canvas.save();
    canvas.clipRect(clipRect);
    _paintDayDotsWithSessionHighlightRing(canvas, plot, metricTrend, range);
    _strokeLeastSquaresTrendAcrossVisibleDates(
      canvas,
      plot,
      metricTrend,
      range,
    );
    canvas.restore();
  }

  void _paintDayDotsWithSessionHighlightRing(
    Canvas canvas,
    ChartDatePlot plot,
    MetricTrend metricTrend,
    PaddedMetricScale range,
  ) {
    final dotPaint = Paint()..color = metricTrend.color;
    final ringPaint = Paint()
      ..color = metricTrend.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final point in metricTrend.points) {
      final pointX = plot.xForDate(point.date);
      final normalized = range.normalize(point.value);
      final pointY = plot.bottom - normalized * plot.height;
      canvas.drawCircle(Offset(pointX, pointY), 3, dotPaint);
      if (_isHighlightedDay(point.date)) {
        canvas.drawCircle(Offset(pointX, pointY), 6, ringPaint);
      }
    }
  }

  bool _isHighlightedDay(DateTime pointDate) {
    final highlight = highlightDate;
    if (highlight == null) return false;
    return pointDate.year == highlight.year &&
        pointDate.month == highlight.month &&
        pointDate.day == highlight.day;
  }

  void _strokeLeastSquaresTrendAcrossVisibleDates(
    Canvas canvas,
    ChartDatePlot plot,
    MetricTrend metricTrend,
    PaddedMetricScale range,
  ) {
    final visiblePoints = metricTrend.points
        .where(
          (point) =>
              !point.date.isBefore(plot.minDate) &&
              !point.date.isAfter(plot.maxDate),
        )
        .toList();

    if (visiblePoints.length < 2) return;

    final trend = leastSquaresTrend(visiblePoints, plot.minDate);
    final dateRangeSeconds = plot.maxDate
        .difference(plot.minDate)
        .inSeconds
        .toDouble();

    final startValue = trend.intercept;
    final endValue = trend.intercept + trend.slope * dateRangeSeconds;

    final startY = plot.bottom - range.normalize(startValue) * plot.height;
    final endY = plot.bottom - range.normalize(endValue) * plot.height;

    final trendPaint = Paint()
      ..color = metricTrend.color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(plot.left, startY),
      Offset(plot.right, endY),
      trendPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MetricTrendPainter oldDelegate) =>
      visibleTrends != oldDelegate.visibleTrends ||
      displayStart != oldDelegate.displayStart ||
      displayEnd != oldDelegate.displayEnd ||
      hoverPosition != oldDelegate.hoverPosition ||
      highlightDate != oldDelegate.highlightDate;
}
