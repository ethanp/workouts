import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class TrendSeries {
  const TrendSeries({
    required this.label,
    required this.color,
    required this.points,
    required this.formatValue,
    this.invertY = false,
  });

  final String label;
  final Color color;
  final List<TrendPoint> points;
  final String Function(double) formatValue;
  final bool invertY;
}

class TrendLine {
  const TrendLine({required this.slope, required this.intercept});

  final double slope;
  final double intercept;

  static const _secondsPerMonth = 30.44 * 24 * 3600;

  double get slopePerMonth => slope * _secondsPerMonth;
}

/// Maps a series' raw values to the [0, 1] range for chart rendering.
///
/// Computes padded min/max from the data points so values don't touch the
/// chart edges. When [invertY] is true (e.g. pace, where lower is better),
/// the mapping is flipped so that "better" values appear higher on the chart.
class SeriesValueScale {
  SeriesValueScale(List<TrendPoint> points, {required this.invertY}) {
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
  final bool invertY;

  double normalize(double value) {
    final range = max - min;
    if (range <= 0) return 0.5;
    final fraction = (value - min) / range;
    return invertY ? 1.0 - fraction : fraction;
  }
}

TrendLine computeTrendLine(List<TrendPoint> points, DateTime origin) {
  final pointCount = points.length;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXY = 0.0;
  var sumX2 = 0.0;

  for (final trendPoint in points) {
    final elapsedSeconds = trendPoint.date.difference(origin).inSeconds.toDouble();
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
