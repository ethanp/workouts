import 'dart:math' as math;

import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/utils/run_formatting.dart';

class BestEffortCalculator {
  List<CardioBestEffort> compute(List<CardioRoutePoint> routePoints) {
    final timedPoints = _timedPointsSortedByTime(routePoints);
    if (timedPoints.length < 2) return const [];

    final cumulativeMeters = _buildCumulativeDistances(timedPoints);
    final totalDistance = cumulativeMeters.last;

    final bestEfforts = <CardioBestEffort>[];
    for (final bucket in DistanceBucket.values) {
      if (totalDistance < bucket.meters) continue;
      final elapsedSeconds = _fastestWindow(timedPoints, cumulativeMeters, bucket.meters);
      if (elapsedSeconds != null) {
        bestEfforts.add(CardioBestEffort(bucket: bucket, elapsedSeconds: elapsedSeconds));
      }
    }
    return bestEfforts;
  }

  List<CardioRoutePoint> _timedPointsSortedByTime(List<CardioRoutePoint> points) {
    final timed = points.where((p) => p.recordedAt != null).toList()
      ..sort((a, b) => a.recordedAt!.compareTo(b.recordedAt!));
    return timed;
  }

  List<double> _buildCumulativeDistances(List<CardioRoutePoint> points) {
    final cumulative = List<double>.filled(points.length, 0.0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] = cumulative[i - 1] +
          _haversineMeters(
            points[i - 1].latitude, points[i - 1].longitude,
            points[i].latitude, points[i].longitude,
          );
    }
    return cumulative;
  }

  /// Finds the minimum elapsed seconds for a continuous stretch of at least
  /// [targetMeters] using a two-pointer sliding window.
  double? _fastestWindow(
    List<CardioRoutePoint> points,
    List<double> cumulativeMeters,
    double targetMeters,
  ) {
    double? bestSeconds;
    var start = 0;

    for (var end = 1; end < points.length; end++) {
      while (cumulativeMeters[end] - cumulativeMeters[start + 1] >= targetMeters) {
        start++;
      }

      final windowDistance = cumulativeMeters[end] - cumulativeMeters[start];
      if (windowDistance < targetMeters) continue;

      final windowSeconds = points[end].recordedAt!
          .difference(points[start].recordedAt!)
          .inMilliseconds / 1000.0;
      if (windowSeconds <= 0) continue;

      if (bestSeconds == null || windowSeconds < bestSeconds) {
        bestSeconds = windowSeconds;
      }
    }

    return bestSeconds;
  }

  static double _haversineMeters(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const earthRadius = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
