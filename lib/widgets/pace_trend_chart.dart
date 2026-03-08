import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/chart_date_axis.dart';

class PacePoint {
  const PacePoint({required this.date, required this.paceSecondsPerUnit});

  final DateTime date;
  final double paceSecondsPerUnit;
}

class PaceTrendChart extends StatelessWidget {
  const PaceTrendChart({
    super.key,
    required this.title,
    required this.points,
    required this.unitLabel,
    this.displayStart,
    this.displayEnd,
  });

  final String title;
  final List<PacePoint> points;
  final String unitLabel;

  /// Override the x-axis date range to align with other charts.
  /// Falls back to the data range when null.
  final DateTime? displayStart;
  final DateTime? displayEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 180, child: _chart()),
        ],
      ),
    );
  }

  Widget _header() {
    if (points.isEmpty) {
      return Text(title, style: AppTypography.subtitle);
    }

    if (points.length < 2) {
      final latest = points.last;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.subtitle),
          Text(
            'latest ${Format.paceValue(latest.paceSecondsPerUnit)}/$unitLabel',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ],
      );
    }

    final minDate = points.first.date;
    final maxDate = points.last.date;
    final dateRangeSeconds =
        maxDate.difference(minDate).inSeconds.toDouble();
    final trend = _computeTrendLine(points, dateRangeSeconds, minDate);

    final slopePerMonth = trend.slope * 30.44 * 24 * 3600;
    final sign = slopePerMonth <= 0 ? '' : '+';
    final slopeLabel = '$sign${slopePerMonth.round()}s/mo';
    final interceptLabel = Format.paceValue(trend.intercept);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTypography.subtitle),
            Text(
              'latest ${Format.paceValue(points.last.paceSecondsPerUnit)}/$unitLabel',
              style:
                  AppTypography.caption.copyWith(color: AppColors.textColor3),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'trend $slopeLabel from $interceptLabel/$unitLabel',
          style: AppTypography.caption.copyWith(color: const Color(0xFFFF9F0A)),
        ),
      ],
    );
  }

  static _TrendLine _computeTrendLine(
      List<PacePoint> points, double dateRange, DateTime minDate) {
    final n = points.length;
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumX2 = 0.0;

    for (final p in points) {
      final x = p.date.difference(minDate).inSeconds.toDouble();
      final y = p.paceSecondsPerUnit;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 1e-10) {
      return _TrendLine(slope: 0, intercept: sumY / n);
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;
    return _TrendLine(slope: slope, intercept: intercept);
  }

  Widget _chart() {
    if (points.length < 2) {
      return const Center(
        child: Text('Need 2+ runs for trend', style: AppTypography.caption),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PaceTrendPainter(
            points: points,
            unitLabel: unitLabel,
            dotColor: AppColors.accentPrimary,
            trendColor: const Color(0xFFFF9F0A),
            labelColor: AppColors.textColor4,
            gridColor: AppColors.borderDepth1,
            displayStart: displayStart,
            displayEnd: displayEnd,
          ),
        );
      },
    );
  }

}

class _PaceTrendPainter extends CustomPainter {
  _PaceTrendPainter({
    required this.points,
    required this.unitLabel,
    required this.dotColor,
    required this.trendColor,
    required this.labelColor,
    required this.gridColor,
    this.displayStart,
    this.displayEnd,
  });

  final List<PacePoint> points;
  final String unitLabel;
  final Color dotColor;
  final Color trendColor;
  final Color labelColor;
  final Color gridColor;
  final DateTime? displayStart;
  final DateTime? displayEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = ChartDateLayout(
      size: size,
      leftPadding: 42,
      rightPadding: 12,
      topPadding: 8,
      bottomPadding: 24,
      minDate: displayStart ?? points.first.date,
      maxDate: displayEnd ?? points.last.date,
    );

    final minPace = points.fold(double.infinity,
        (m, p) => math.min(m, p.paceSecondsPerUnit));
    final maxPace = points.fold(0.0,
        (m, p) => math.max(m, p.paceSecondsPerUnit));
    final paceRange = maxPace - minPace;
    final paddedMin = minPace - paceRange * 0.15;
    final paddedMax = maxPace + paceRange * 0.15;
    final effectiveRange = paddedMax - paddedMin;

    double yForPace(double pace) {
      if (effectiveRange == 0) return layout.top + layout.height / 2;
      final fraction = (pace - paddedMin) / effectiveRange;
      return layout.bottom - (1.0 - fraction) * layout.height;
    }

    _drawGridLines(canvas, layout, paddedMin, paddedMax);
    drawChartYearBoundaries(canvas, layout);
    drawChartDateLabels(canvas, layout, labelColor: labelColor);

    final dateRange =
        layout.maxDate.difference(layout.minDate).inSeconds.toDouble();
    final trendLine =
        PaceTrendChart._computeTrendLine(points, dateRange, layout.minDate);

    final trendPaint = Paint()
      ..color = trendColor.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final startPace = trendLine.intercept;
    final endPace = trendLine.intercept + trendLine.slope * dateRange;
    canvas.drawLine(
      Offset(layout.left, yForPace(startPace)),
      Offset(layout.right, yForPace(endPace)),
      trendPaint,
    );

    final dotPaint = Paint()..color = dotColor;
    final dotBorderPaint = Paint()
      ..color = dotColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final p in points) {
      final x = layout.xForDate(p.date);
      final y = yForPace(p.paceSecondsPerUnit);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 6, dotBorderPaint);
    }
  }

  void _drawGridLines(
    Canvas canvas,
    ChartDateLayout layout,
    double minPace,
    double maxPace,
  ) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    final range = maxPace - minPace;
    if (range <= 0) return;

    final stepSeconds = _niceStep(range, 4);
    final firstLine = (minPace / stepSeconds).ceil() * stepSeconds;

    for (var pace = firstLine; pace <= maxPace; pace += stepSeconds) {
      final fraction = (pace - minPace) / range;
      final y = layout.bottom - (1.0 - fraction) * layout.height;
      canvas.drawLine(
        Offset(layout.left, y),
        Offset(layout.right, y),
        gridPaint,
      );

      final label = Format.paceValue(pace);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(layout.left - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }

  double _niceStep(double range, int targetLines) {
    final rough = range / targetLines;
    if (rough <= 15) return 15;
    if (rough <= 30) return 30;
    if (rough <= 60) return 60;
    return (rough / 60).ceil() * 60;
  }

  @override
  bool shouldRepaint(covariant _PaceTrendPainter oldDelegate) =>
      points != oldDelegate.points;
}

class _TrendLine {
  const _TrendLine({required this.slope, required this.intercept});

  final double slope;
  final double intercept;
}
