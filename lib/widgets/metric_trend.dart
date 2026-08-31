import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class const TrendPoint({
  required final DateTime date,
  required final double value,
});

class const MetricTrend({
  required final String label,
  required final Color color,
  required final List<TrendPoint> points,
  required final String Function(double) formatValue,
  final bool lowerIsBetter = false,
});

class const TrendLine({
  required final double slope,
  required final double intercept,
}) {
  static const _secondsPerMonth = 30.44 * 24 * 3600;

  double get slopePerMonth => slope * _secondsPerMonth;
}

class PaddedMetricScale(
  List<TrendPoint> points, {
  required final bool lowerIsBetter,
}) {
  this {
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final trendPoint in points) {
      lo = math.min(lo, trendPoint.value);
      hi = math.max(hi, trendPoint.value);
    }
    final padding = (hi - lo) * 0.15;
    min = lo - padding;
    max = hi + padding;
  }

  late final double min;
  late final double max;
  double normalize(double value) {
    final range = max - min;
    if (range <= 0) return 0.5;
    final fraction = (value - min) / range;
    return lowerIsBetter ? 1.0 - fraction : fraction;
  }
}

TrendLine leastSquaresTrend(List<TrendPoint> points, DateTime origin) {
  final pointCount = points.length;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXY = 0.0;
  var sumX2 = 0.0;

  for (final trendPoint in points) {
    final elapsedSeconds = trendPoint.date
        .difference(origin)
        .inSeconds
        .toDouble();
    final pointValue = trendPoint.value;
    sumX += elapsedSeconds;
    sumY += pointValue;
    sumXY += elapsedSeconds * pointValue;
    sumX2 += elapsedSeconds * elapsedSeconds;
  }

  final denominator = pointCount * sumX2 - sumX * sumX;
  if (denominator.abs() < 1e-10) {
    return TrendLine(slope: 0, intercept: sumY / pointCount);
  }

  final slope = (pointCount * sumXY - sumX * sumY) / denominator;
  final intercept = (sumY - slope * sumX) / pointCount;
  return TrendLine(slope: slope, intercept: intercept);
}
