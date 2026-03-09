import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/momentum_scorer.dart';
import 'package:workouts/widgets/chart_date_axis.dart';

export 'package:workouts/utils/momentum_scorer.dart'
    show MomentumDayScore, MomentumScorer;

class FitnessMomentumChart extends StatelessWidget {
  const FitnessMomentumChart({
    super.key,
    required this.days,
    this.displayStart,
    this.displayEnd,
  });

  final List<ActivityCalendarDay> days;

  /// Override the x-axis date range to align with other charts.
  /// Falls back to the score data range when null.
  final DateTime? displayStart;
  final DateTime? displayEnd;

  static const _scorer = MomentumScorer();

  @override
  Widget build(BuildContext context) {
    final scores = _scorer.compute(days);

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
          _header(scores),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 180, child: _chart(scores)),
        ],
      ),
    );
  }

  Widget _header(List<MomentumDayScore> scores) {
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

  Widget _chart(List<MomentumDayScore> scores) {
    if (scores.length < 2) {
      return const Center(
        child: Text('Need more activity data', style: AppTypography.caption),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _MomentumPainter(
            scores: scores,
            displayStart: displayStart,
            displayEnd: displayEnd,
          ),
        );
      },
    );
  }

  static Color _scoreColor(double score) {
    if (score >= 50) return const Color(0xFF30D158);
    if (score >= 25) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }
}

class _MomentumLayout extends ChartDateLayout {
  _MomentumLayout(
    Size size,
    this.scores, {
    DateTime? displayStart,
    DateTime? displayEnd,
  }) : super(
          size: size,
          leftPadding: 32,
          rightPadding: 12,
          topPadding: 8,
          bottomPadding: 24,
          minDate: displayStart ?? scores.first.date,
          maxDate: displayEnd ?? scores.last.date,
        ) {
    final maxScore =
        scores.fold(0.0, (maxSoFar, point) => math.max(maxSoFar, point.score));
    yMax = math.max(maxScore * 1.15, 10.0).clamp(0.0, 105.0);
  }

  final List<MomentumDayScore> scores;
  late final double yMax;

  static const _lineColor = Color(0xFF30D158);

  double yForScore(double score) => bottom - (score / yMax) * height;

  void paintAll(Canvas canvas) {
    _drawGrid(canvas);
    drawAxes(canvas);
    drawYearBoundaries(canvas);
    drawDateLabels(canvas);
    _drawFill(canvas);
    _drawLine(canvas);
    _drawEndpoint(canvas);
  }

  void _drawGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    final step = yMax > 60 ? 25.0 : (yMax > 30 ? 10.0 : 5.0);

    for (var val = step; val < yMax; val += step) {
      final y = yForScore(val);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${val.round()}%',
          style: TextStyle(color: AppColors.textColor4, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(left - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }

  void _drawFill(Canvas canvas) {
    final fillPath = Path();
    for (var i = 0; i < scores.length; i++) {
      final x = xForDate(scores[i].date);
      final y = yForScore(scores[i].score);
      if (i == 0) {
        fillPath.moveTo(x, bottom);
        fillPath.lineTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(xForDate(scores.last.date), bottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, top),
        Offset(0, bottom),
        [
          _lineColor.withValues(alpha: 0.35),
          _lineColor.withValues(alpha: 0.02),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawLine(Canvas canvas) {
    final path = Path();
    for (var i = 0; i < scores.length; i++) {
      final x = xForDate(scores[i].date);
      final y = yForScore(scores[i].score);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawEndpoint(Canvas canvas) {
    final lastX = xForDate(scores.last.date);
    final lastY = yForScore(scores.last.score);
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = _lineColor);
  }
}

class _MomentumPainter extends CustomPainter {
  _MomentumPainter({
    required this.scores,
    this.displayStart,
    this.displayEnd,
  });

  final List<MomentumDayScore> scores;
  final DateTime? displayStart;
  final DateTime? displayEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _MomentumLayout(
      size,
      scores,
      displayStart: displayStart,
      displayEnd: displayEnd,
    );
    layout.paintAll(canvas);
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) =>
      scores != oldDelegate.scores;
}
