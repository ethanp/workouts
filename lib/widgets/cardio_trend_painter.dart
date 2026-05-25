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
    this.highlightDate,
  });

  final List<TrendSeries> visibleSeries;
  final DateTime? displayStart;
  final DateTime? displayEnd;
  final Offset? hoverPosition;
  final DateTime? highlightDate;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _buildLayout(size);
    _drawBackground(canvas, layout);
    for (final series in visibleSeries) {
      if (series.points.length < 2) continue;
      _drawSeries(canvas, layout, series);
    }
    _drawSeriesAxisLabels(canvas, layout);
    if (hoverPosition != null) {
      ChartTooltip(
        canvas: canvas,
        layout: layout,
        hoverPosition: hoverPosition!,
        visibleSeries: visibleSeries,
      ).paint();
    }
  }

  /// Per-series min/max labels stacked at the top-left and bottom-left of
  /// the plot. Each visible series gets one row at each extreme, color-
  /// coded to match its line, so the chart has the equivalent of a y-axis
  /// without trying to share one across series with different units.
  ///
  /// Labels are drawn last (over the data) so they remain readable when
  /// dots sit near the corners. The slight visual offset between the
  /// corner and the actual top/bottom data point comes from the 15% scale
  /// padding in [SeriesValueScale]; we accept it because the alternative
  /// (no padding) makes dots touch the chart edges.
  void _drawSeriesAxisLabels(Canvas canvas, ChartDateLayout layout) {
    const double rowHeight = 11;
    const double horizontalInset = 4;
    double topCursorY = layout.top + 2;
    double bottomCursorY = layout.bottom - 2 - rowHeight;
    for (final series in visibleSeries) {
      if (series.points.length < 2) continue;
      final values = series.points.map((point) => point.value);
      final hi = values.reduce((largest, current) =>
          current > largest ? current : largest);
      final lo = values.reduce((smallest, current) =>
          current < smallest ? current : smallest);
      final highLabel = series.invertY ? lo : hi;
      final lowLabel = series.invertY ? hi : lo;
      _drawAxisLabel(
        canvas: canvas,
        text: series.formatValue(highLabel),
        position: Offset(layout.left + horizontalInset, topCursorY),
        color: series.color,
      );
      _drawAxisLabel(
        canvas: canvas,
        text: series.formatValue(lowLabel),
        position: Offset(layout.left + horizontalInset, bottomCursorY),
        color: series.color,
      );
      topCursorY += rowHeight;
      bottomCursorY -= rowHeight;
    }
  }

  void _drawAxisLabel({
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

  ChartDateLayout _buildLayout(Size size) {
    final allDates = visibleSeries
        .expand((trendSeries) => trendSeries.points)
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
    for (var lineIndex = 0; lineIndex <= lineCount; lineIndex++) {
      final fraction = lineIndex / lineCount;
      final lineY = layout.top + fraction * layout.height;
      canvas.drawLine(
        Offset(layout.left, lineY),
        Offset(layout.right, lineY),
        gridPaint,
      );
    }
  }

  void _drawSeries(Canvas canvas, ChartDateLayout layout, TrendSeries series) {
    final range = SeriesValueScale(series.points, invertY: series.invertY);

    final clipRect = Rect.fromLTRB(
      layout.left,
      layout.top,
      layout.right,
      layout.bottom,
    );
    canvas.save();
    canvas.clipRect(clipRect);
    _drawSeriesDots(canvas, layout, series, range);
    _drawSeriesTrendLine(canvas, layout, series, range);
    canvas.restore();
  }

  void _drawSeriesDots(
    Canvas canvas,
    ChartDateLayout layout,
    TrendSeries series,
    SeriesValueScale range,
  ) {
    final dotPaint = Paint()..color = series.color;
    final ringPaint = Paint()
      ..color = series.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final point in series.points) {
      final pointX = layout.xForDate(point.date);
      final normalized = range.normalize(point.value);
      final pointY = layout.bottom - normalized * layout.height;
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

  void _drawSeriesTrendLine(
    Canvas canvas,
    ChartDateLayout layout,
    TrendSeries series,
    SeriesValueScale range,
  ) {
    final visiblePoints = series.points
        .where(
          (point) =>
              !point.date.isBefore(layout.minDate) &&
              !point.date.isAfter(layout.maxDate),
        )
        .toList();

    if (visiblePoints.length < 2) return;

    final trend = computeTrendLine(visiblePoints, layout.minDate);
    final dateRangeSeconds = layout.maxDate
        .difference(layout.minDate)
        .inSeconds
        .toDouble();

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
      hoverPosition != oldDelegate.hoverPosition ||
      highlightDate != oldDelegate.highlightDate;
}
