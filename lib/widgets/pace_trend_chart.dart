import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

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
  });

  final String title;
  final List<PacePoint> points;
  final String unitLabel;

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
  });

  final List<PacePoint> points;
  final String unitLabel;
  final Color dotColor;
  final Color trendColor;
  final Color labelColor;
  final Color gridColor;

  static const _leftPadding = 42.0;
  static const _rightPadding = 12.0;
  static const _topPadding = 8.0;
  static const _bottomPadding = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPadding;
    final chartRight = size.width - _rightPadding;
    final chartTop = _topPadding;
    final chartBottom = size.height - _bottomPadding;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    final minPace = points.fold(double.infinity,
        (m, p) => math.min(m, p.paceSecondsPerUnit));
    final maxPace = points.fold(0.0,
        (m, p) => math.max(m, p.paceSecondsPerUnit));
    final paceRange = maxPace - minPace;
    final paddedMin = minPace - paceRange * 0.15;
    final paddedMax = maxPace + paceRange * 0.15;
    final effectiveRange = paddedMax - paddedMin;

    final minDate = points.first.date;
    final maxDate = points.last.date;
    final dateRange = maxDate.difference(minDate).inSeconds.toDouble();

    double xForDate(DateTime date) {
      if (dateRange == 0) return chartLeft + chartWidth / 2;
      final fraction = date.difference(minDate).inSeconds / dateRange;
      return chartLeft + fraction * chartWidth;
    }

    double yForPace(double pace) {
      if (effectiveRange == 0) return chartTop + chartHeight / 2;
      final fraction = (pace - paddedMin) / effectiveRange;
      return chartBottom - (1.0 - fraction) * chartHeight;
    }

    _drawGridLines(canvas, size, chartLeft, chartRight, chartTop, chartBottom,
        paddedMin, paddedMax);

    _drawDateLabels(canvas, chartBottom, minDate, maxDate, xForDate);

    final trendLine =
        PaceTrendChart._computeTrendLine(points, dateRange, minDate);

    final trendPaint = Paint()
      ..color = trendColor.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final startX = chartLeft;
    final endX = chartRight;
    final startPace = trendLine.intercept;
    final endPace = trendLine.intercept + trendLine.slope * dateRange;
    canvas.drawLine(
      Offset(startX, yForPace(startPace)),
      Offset(endX, yForPace(endPace)),
      trendPaint,
    );

    final dotPaint = Paint()..color = dotColor;
    final dotBorderPaint = Paint()
      ..color = dotColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final p in points) {
      final x = xForDate(p.date);
      final y = yForPace(p.paceSecondsPerUnit);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 6, dotBorderPaint);
    }
  }

  void _drawGridLines(Canvas canvas, Size size, double left, double right,
      double top, double bottom, double minPace, double maxPace) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    final range = maxPace - minPace;
    if (range <= 0) return;

    final stepSeconds = _niceStep(range, 4);
    final firstLine = (minPace / stepSeconds).ceil() * stepSeconds;

    for (var pace = firstLine; pace <= maxPace; pace += stepSeconds) {
      final fraction = (pace - minPace) / range;
      final y = bottom - (1.0 - fraction) * (bottom - top);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

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
        Offset(left - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }

  void _drawDateLabels(Canvas canvas, double chartBottom, DateTime minDate,
      DateTime maxDate, double Function(DateTime) xForDate) {
    final spansDays = maxDate.difference(minDate).inDays;

    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String formatLabel(DateTime date) {
      final mon = months[date.month];
      if (spansDays > 365) return "$mon '${date.year % 100}";
      if (spansDays > 60) return mon;
      return '${date.month}/${date.day}';
    }

    final ticks = _dateTicks(minDate, maxDate);
    for (final date in ticks) {
      final label = formatLabel(date);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = (xForDate(date) - textPainter.width / 2)
          .clamp(_leftPadding - 4, _leftPadding + 400);
      textPainter.paint(canvas, Offset(x, chartBottom + 6));
    }
  }

  List<DateTime> _dateTicks(DateTime minDate, DateTime maxDate) {
    final spansDays = maxDate.difference(minDate).inDays;

    if (spansDays > 90) {
      final ticks = <DateTime>[];
      var cursor = DateTime(minDate.year, minDate.month);
      final stepMonths = spansDays > 365 ? 3 : 2;
      cursor = DateTime(cursor.year, cursor.month + stepMonths);
      while (cursor.isBefore(maxDate)) {
        ticks.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + stepMonths);
      }
      return [minDate, ...ticks, maxDate];
    }

    if (spansDays > 14) {
      final ticks = <DateTime>[minDate];
      final stepDays = (spansDays / 5).round().clamp(7, 30);
      var cursor = minDate.add(Duration(days: stepDays));
      while (cursor.isBefore(maxDate.subtract(Duration(days: stepDays ~/ 2)))) {
        ticks.add(cursor);
        cursor = cursor.add(Duration(days: stepDays));
      }
      ticks.add(maxDate);
      return ticks;
    }

    return [minDate, maxDate];
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
