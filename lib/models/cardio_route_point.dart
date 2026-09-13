import 'dart:math' as math;

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/distance_bucket.dart';

class const CardioRoutePoint({
  required final String id,
  required final String workoutId,
  required final int pointIndex,
  required final double latitude,
  required final double longitude,
  final double? altitudeMeters,
  final DateTime? recordedAt,
  final DateTime? createdAt,
  final DateTime? updatedAt,
}) {
  factory fromRow(Map<String, dynamic> routePointRow) {
    return CardioRoutePoint(
      id: routePointRow['id'] as String,
      workoutId: routePointRow['workout_id'] as String,
      pointIndex: (routePointRow['point_index'] as int?) ?? 0,
      latitude: _asDouble(routePointRow['lat']) ?? 0,
      longitude: _asDouble(routePointRow['lng']) ?? 0,
      altitudeMeters: _asDouble(routePointRow['altitude_meters']),
      recordedAt: _asDateTime(routePointRow['timestamp']),
      createdAt: _asDateTime(routePointRow['created_at']),
      updatedAt: _asDateTime(routePointRow['updated_at']),
    );
  }

  double metersTo(CardioRoutePoint other) {
    const earthRadius = 6371000.0;
    final phi1 = latitude.deg2rad;
    final phi2 = other.latitude.deg2rad;
    final dPhi = (other.latitude - latitude).deg2rad;
    final dLambda = (other.longitude - longitude).deg2rad;
    final haversine =
        math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    return earthRadius *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }
}

extension CardioRouteBestEfforts on List<CardioRoutePoint> {
  List<CardioBestEffort> get bestEfforts => _RouteBestEfforts(this).compute();
}

class _RouteBestEfforts {
  const _RouteBestEfforts(this.routePoints);

  final List<CardioRoutePoint> routePoints;

  List<CardioBestEffort> compute() {
    final timedPoints = _timedPointsSortedByTime();
    if (timedPoints.length < 2) return const [];

    final cumulativeMeters = _cumulativeDistances(timedPoints);
    final totalDistance = cumulativeMeters.last;

    final bestEfforts = <CardioBestEffort>[];
    for (final bucket in DistanceBucket.values) {
      if (totalDistance < bucket.meters) continue;
      final elapsedSeconds = _fastestWindow(
        timedPoints,
        cumulativeMeters,
        bucket.meters,
      );
      if (elapsedSeconds != null) {
        bestEfforts.add(
          CardioBestEffort(bucket: bucket, elapsedSeconds: elapsedSeconds),
        );
      }
    }
    return bestEfforts;
  }

  List<CardioRoutePoint> _timedPointsSortedByTime() {
    return routePoints.where((routePoint) => routePoint.recordedAt != null).toList()
      ..sort(
        (firstPoint, secondPoint) =>
            firstPoint.recordedAt!.compareTo(secondPoint.recordedAt!),
      );
  }

  List<double> _cumulativeDistances(List<CardioRoutePoint> points) {
    final cumulative = List<double>.filled(points.length, 0.0);
    for (var pointIndex = 1; pointIndex < points.length; pointIndex++) {
      cumulative[pointIndex] =
          cumulative[pointIndex - 1] +
          points[pointIndex - 1].metersTo(points[pointIndex]);
    }
    return cumulative;
  }

  double? _fastestWindow(
    List<CardioRoutePoint> points,
    List<double> cumulativeMeters,
    double targetMeters,
  ) {
    double? bestSeconds;
    var start = 0;

    for (var end = 1; end < points.length; end++) {
      while (cumulativeMeters[end] - cumulativeMeters[start + 1] >=
          targetMeters) {
        start++;
      }

      final windowDistance = cumulativeMeters[end] - cumulativeMeters[start];
      if (windowDistance < targetMeters) continue;

      final windowSeconds =
          points[end].recordedAt!
              .difference(points[start].recordedAt!)
              .inMilliseconds /
          1000.0;
      if (windowSeconds <= 0) continue;

      if (bestSeconds == null || windowSeconds < bestSeconds) {
        bestSeconds = windowSeconds;
      }
    }

    return bestSeconds;
  }
}

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
