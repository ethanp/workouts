import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/theme/app_theme.dart';

class FitnessMomentumChart extends StatelessWidget {
  const FitnessMomentumChart({
    super.key,
    required this.days,
  });

  final List<ActivityCalendarDay> days;

  static const _windowDays = 30;
  static const _fullWeightDays = 7;

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
    final scores = _computeScores();
    if (scores.isEmpty) {
      return Text('Fitness Momentum', style: AppTypography.subtitle);
    }

    final current = scores.last.score;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Fitness Momentum', style: AppTypography.subtitle),
        Text(
          '${current.round()}%',
          style: AppTypography.subtitle.copyWith(
            color: _scoreColor(current),
          ),
        ),
      ],
    );
  }

  Widget _chart() {
    final scores = _computeScores();
    if (scores.length < 2) {
      return const Center(
        child: Text(
          'Need more activity data',
          style: AppTypography.caption,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _MomentumPainter(
            scores: scores,
            lineColor: const Color(0xFF30D158),
            labelColor: AppColors.textColor4,
            gridColor: AppColors.borderDepth1,
          ),
        );
      },
    );
  }

  List<_DayScore> _computeScores() {
    if (days.isEmpty) return [];

    final activityByDate = <DateTime, ActivityCalendarDay>{};
    for (final d in days) {
      activityByDate[d.date] = d;
    }

    final sortedDates = days.map((d) => d.date).toList()
      ..sort((a, b) => a.compareTo(b));
    final earliest = sortedDates.first;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final startDate = earliest.add(const Duration(days: _windowDays));
    if (startDate.isAfter(todayDate)) {
      if (todayDate.difference(earliest).inDays < 7) return [];
    }

    final effectiveStart = startDate.isAfter(todayDate)
        ? earliest.add(const Duration(days: 7))
        : startDate;

    final scores = <_DayScore>[];
    var cursor = effectiveStart;
    while (!cursor.isAfter(todayDate)) {
      var score = 0.0;
      var maxPossible = 0.0;

      for (var daysAgo = 0; daysAgo < _windowDays; daysAgo++) {
        final checkDate = cursor.subtract(Duration(days: daysAgo));
        final weight = _weight(daysAgo);
        maxPossible += weight;

        final dayData = activityByDate[checkDate];
        if (dayData != null && dayData.hasActivity) {
          score += weight;
        }
      }

      final percentage = maxPossible > 0 ? (score / maxPossible) * 100 : 0.0;
      scores.add(_DayScore(date: cursor, score: percentage));
      cursor = cursor.add(const Duration(days: 1));
    }

    return scores;
  }

  static double _weight(int daysAgo) {
    if (daysAgo <= _fullWeightDays) return 1.0;
    return 1.0 - ((daysAgo - _fullWeightDays) / (_windowDays - _fullWeightDays) * 0.9);
  }

  static Color _scoreColor(double score) {
    if (score >= 50) return const Color(0xFF30D158);
    if (score >= 25) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }
}

class _DayScore {
  const _DayScore({required this.date, required this.score});

  final DateTime date;
  final double score;
}

class _MomentumPainter extends CustomPainter {
  _MomentumPainter({
    required this.scores,
    required this.lineColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<_DayScore> scores;
  final Color lineColor;
  final Color labelColor;
  final Color gridColor;

  static const _leftPadding = 32.0;
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

    final maxScore = scores.fold(0.0, (m, s) => math.max(m, s.score));
    final yMax = math.max(maxScore * 1.15, 10.0).clamp(0.0, 105.0);

    final minDate = scores.first.date;
    final maxDate = scores.last.date;
    final dateRange = maxDate.difference(minDate).inSeconds.toDouble();

    double xForDate(DateTime date) {
      if (dateRange == 0) return chartLeft + chartWidth / 2;
      return chartLeft +
          (date.difference(minDate).inSeconds / dateRange) * chartWidth;
    }

    double yForScore(double score) {
      return chartBottom - (score / yMax) * chartHeight;
    }

    _drawGrid(canvas, chartLeft, chartRight, chartTop, chartBottom, yMax);
    _drawDateLabels(canvas, chartBottom, minDate, maxDate, xForDate);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < scores.length; i++) {
      final x = xForDate(scores[i].date);
      final y = yForScore(scores[i].score);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartBottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(xForDate(scores.last.date), chartBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, chartTop),
        Offset(0, chartBottom),
        [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.02),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final lastX = xForDate(scores.last.date);
    final lastY = yForScore(scores.last.score);
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = lineColor,
    );
  }

  void _drawGrid(Canvas canvas, double left, double right, double top,
      double bottom, double yMax) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    final step = yMax > 60 ? 25.0 : (yMax > 30 ? 10.0 : 5.0);

    for (var val = step; val < yMax; val += step) {
      final y = bottom - (val / yMax) * (bottom - top);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${val.round()}%',
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
    final spanDays = maxDate.difference(minDate).inDays;

    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String formatLabel(DateTime date) {
      final mon = months[date.month];
      if (spanDays > 365) return "$mon '${date.year % 100}";
      if (spanDays > 60) return mon;
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
    final spanDays = maxDate.difference(minDate).inDays;

    if (spanDays > 90) {
      final ticks = <DateTime>[];
      final stepMonths = spanDays > 365 ? 3 : 2;
      var cursor = DateTime(minDate.year, minDate.month + stepMonths);
      while (cursor.isBefore(maxDate)) {
        ticks.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + stepMonths);
      }
      return [minDate, ...ticks, maxDate];
    }

    if (spanDays > 14) {
      final ticks = <DateTime>[minDate];
      final stepDays = (spanDays / 5).round().clamp(7, 30);
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

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) =>
      scores != oldDelegate.scores;
}
