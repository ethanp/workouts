import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/distance_bucket.dart';

CardioRoutePoint _point({
  required int index,
  required double lat,
  required double lng,
  required DateTime recordedAt,
}) => CardioRoutePoint(
  id: 'pt-$index',
  workoutId: 'w1',
  pointIndex: index,
  latitude: lat,
  longitude: lng,
  recordedAt: recordedAt,
);

/// Creates a straight-line route of [count] evenly spaced points heading due
/// east from (0, 0). Each pair of consecutive points is ~111 meters apart
/// (0.001 degrees of longitude at the equator), and [secondsBetween] apart
/// in time. Total distance ≈ (count - 1) * 111 m.
List<CardioRoutePoint> _straightRoute({
  required int count,
  int secondsBetween = 30,
}) {
  final start = DateTime(2026, 3, 1, 8, 0, 0);
  return List.generate(
    count,
    (i) => _point(
      index: i,
      lat: 0.0,
      lng: i * 0.001,
      recordedAt: start.add(Duration(seconds: i * secondsBetween)),
    ),
  );
}

void main() {
  group('CardioRoutePoint.bestEfforts', () {
    test('returns empty for fewer than 2 points', () {
      final single = [
        _point(index: 0, lat: 0, lng: 0, recordedAt: DateTime(2026)),
      ];
      expect(single.bestEfforts, isEmpty);
      expect(<CardioRoutePoint>[].bestEfforts, isEmpty);
    });

    test('returns empty when no points have timestamps', () {
      final noTimestamps = [
        CardioRoutePoint(
          id: 'a',
          workoutId: 'w',
          pointIndex: 0,
          latitude: 0,
          longitude: 0,
        ),
        CardioRoutePoint(
          id: 'b',
          workoutId: 'w',
          pointIndex: 1,
          latitude: 0,
          longitude: 0.01,
        ),
      ];
      expect(noTimestamps.bestEfforts, isEmpty);
    });

    test('skips buckets where total distance is insufficient', () {
      final shortRoute = _straightRoute(count: 4);
      expect(shortRoute.bestEfforts, isEmpty);
    });

    test('computes 400m best effort for a route just over 400m', () {
      final route = _straightRoute(count: 5);
      final results = route.bestEfforts;
      expect(results.length, 1);
      expect(results.first.bucket, DistanceBucket.fourHundredMeters);
      expect(results.first.elapsedSeconds, greaterThan(0));
    });

    test('computes multiple buckets for a long route', () {
      final route = _straightRoute(count: 26, secondsBetween: 20);
      final results = route.bestEfforts;

      final buckets = results.map((result) => result.bucket).toSet();
      expect(buckets, contains(DistanceBucket.fourHundredMeters));
      expect(buckets, contains(DistanceBucket.halfMile));
      expect(buckets, contains(DistanceBucket.oneMile));
      expect(buckets.contains(DistanceBucket.fiveK), isFalse);
    });

    test('fastest window is chosen when pace varies', () {
      final start = DateTime(2026, 3, 1, 8, 0, 0);
      final route = <CardioRoutePoint>[];
      for (var i = 0; i < 5; i++) {
        route.add(
          _point(
            index: i,
            lat: 0,
            lng: i * 0.001,
            recordedAt: start.add(Duration(seconds: i * 60)),
          ),
        );
      }
      for (var i = 5; i < 10; i++) {
        route.add(
          _point(
            index: i,
            lat: 0,
            lng: i * 0.001,
            recordedAt: start.add(Duration(seconds: 4 * 60 + (i - 4) * 10)),
          ),
        );
      }

      final fourHundred = route.bestEfforts.firstWhere(
        (result) => result.bucket == DistanceBucket.fourHundredMeters,
      );
      expect(fourHundred.elapsedSeconds, lessThan(60));
    });

    test('points without timestamps are filtered out', () {
      final start = DateTime(2026, 3, 1, 8, 0, 0);
      final route = <CardioRoutePoint>[
        _point(index: 0, lat: 0, lng: 0, recordedAt: start),
        CardioRoutePoint(
          id: 'no-time',
          workoutId: 'w1',
          pointIndex: 1,
          latitude: 0,
          longitude: 0.001,
        ),
        ...List.generate(
          5,
          (i) => _point(
            index: i + 2,
            lat: 0,
            lng: (i + 2) * 0.001,
            recordedAt: start.add(Duration(seconds: (i + 1) * 30)),
          ),
        ),
      ];
      expect(route.bestEfforts, isNotEmpty);
    });

    test('elapsed seconds reflect actual time between window endpoints', () {
      final route = _straightRoute(count: 6, secondsBetween: 30);
      final fourHundred = route.bestEfforts.firstWhere(
        (result) => result.bucket == DistanceBucket.fourHundredMeters,
      );
      expect(fourHundred.elapsedSeconds, closeTo(120, 1));
    });
  });

  group('CardioBestEffort.paceSecondsPerUnit', () {
    test('converts elapsed seconds to pace per mile', () {
      final effort = _straightRoute(count: 5).bestEfforts.first;
      final pacePerMile = effort.paceSecondsPerUnit(metersPerMile);
      expect(pacePerMile, greaterThan(0));
    });
  });

  group('DistanceBucket', () {
    test('fromMeters resolves known buckets', () {
      expect(DistanceBucket.fromMeters(400), DistanceBucket.fourHundredMeters);
      expect(DistanceBucket.fromMeters(metersPerMile), DistanceBucket.oneMile);
      expect(DistanceBucket.fromMeters(5000), DistanceBucket.fiveK);
    });

    test('fromMeters returns null for unknown values', () {
      expect(DistanceBucket.fromMeters(999), isNull);
    });

    test('bucket meters are correctly derived from metersPerMile', () {
      expect(DistanceBucket.halfMile.meters, closeTo(metersPerMile / 2, 0.01));
      expect(DistanceBucket.oneMile.meters, closeTo(metersPerMile, 0.01));
      expect(DistanceBucket.fiveMiles.meters, closeTo(metersPerMile * 5, 0.01));
    });
  });
}
