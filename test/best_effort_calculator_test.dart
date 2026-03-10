import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/utils/best_effort_calculator.dart';
import 'package:workouts/utils/run_formatting.dart';

final _calculator = BestEffortCalculator();

CardioRoutePoint _point({
  required int index,
  required double lat,
  required double lng,
  required DateTime recordedAt,
}) =>
    CardioRoutePoint(
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
  group('BestEffortCalculator', () {
    test('returns empty for fewer than 2 points', () {
      final single = [
        _point(index: 0, lat: 0, lng: 0, recordedAt: DateTime(2026)),
      ];
      expect(_calculator.compute(single), isEmpty);
      expect(_calculator.compute([]), isEmpty);
    });

    test('returns empty when no points have timestamps', () {
      final noTimestamps = [
        CardioRoutePoint(
            id: 'a', workoutId: 'w', pointIndex: 0, latitude: 0, longitude: 0),
        CardioRoutePoint(
            id: 'b',
            workoutId: 'w',
            pointIndex: 1,
            latitude: 0,
            longitude: 0.01),
      ];
      expect(_calculator.compute(noTimestamps), isEmpty);
    });

    test('skips buckets where total distance is insufficient', () {
      // ~333 m route (4 points * ~111m spacing) — only 400m bucket is too big
      final shortRoute = _straightRoute(count: 4);
      final results = _calculator.compute(shortRoute);
      expect(results, isEmpty);
    });

    test('computes 400m best effort for a route just over 400m', () {
      // 5 points * ~111m = ~444m total — enough for 400m bucket only
      final route = _straightRoute(count: 5);
      final results = _calculator.compute(route);
      expect(results.length, 1);
      expect(results.first.bucket, DistanceBucket.fourHundredMeters);
      expect(results.first.elapsedSeconds, greaterThan(0));
    });

    test('computes multiple buckets for a long route', () {
      // ~2.8 km route — should cover 400m, 1/2 mi, 1 mi
      final route = _straightRoute(count: 26, secondsBetween: 20);
      final results = _calculator.compute(route);

      final buckets = results.map((r) => r.bucket).toSet();
      expect(buckets, contains(DistanceBucket.fourHundredMeters));
      expect(buckets, contains(DistanceBucket.halfMile));
      expect(buckets, contains(DistanceBucket.oneMile));
      expect(buckets.contains(DistanceBucket.fiveK), isFalse);
    });

    test('fastest window is chosen when pace varies', () {
      final start = DateTime(2026, 3, 1, 8, 0, 0);
      // First 5 points: slow (60s apart), last 5 points: fast (10s apart)
      // Each pair ~111m apart
      final route = <CardioRoutePoint>[];
      for (var i = 0; i < 5; i++) {
        route.add(_point(
          index: i,
          lat: 0,
          lng: i * 0.001,
          recordedAt: start.add(Duration(seconds: i * 60)),
        ));
      }
      for (var i = 5; i < 10; i++) {
        route.add(_point(
          index: i,
          lat: 0,
          lng: i * 0.001,
          recordedAt:
              start.add(Duration(seconds: 4 * 60 + (i - 4) * 10)),
        ));
      }

      final results = _calculator.compute(route);
      final fourHundred = results.firstWhere(
        (r) => r.bucket == DistanceBucket.fourHundredMeters,
      );

      // The fast section covers ~555m in 50s (points 5-9).
      // The slow section covers ~444m in 240s (points 0-4).
      // Best 400m should come from the fast section.
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
      // Should still compute — the no-timestamp point is skipped
      final results = _calculator.compute(route);
      expect(results, isNotEmpty);
    });

    test('elapsed seconds reflect actual time between window endpoints', () {
      // 6 points, 30s apart, ~111m each = ~555m in 150s
      final route = _straightRoute(count: 6, secondsBetween: 30);
      final results = _calculator.compute(route);
      final fourHundred = results.firstWhere(
        (r) => r.bucket == DistanceBucket.fourHundredMeters,
      );
      // 400m needs ~4 segments of 111m = requires spanning at least 4 gaps
      // Best window should be ~120s (4 gaps * 30s)
      expect(fourHundred.elapsedSeconds, closeTo(120, 1));
    });
  });

  group('CardioBestEffort.paceSecondsPerUnit', () {
    test('converts elapsed seconds to pace per mile', () {
      final effort = _calculator.compute(_straightRoute(count: 5)).first;
      final pacePerMile = effort.paceSecondsPerUnit(metersPerMile);
      // 400m bucket, so pace = elapsed * (metersPerMile / 400)
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
      expect(
          DistanceBucket.fiveMiles.meters, closeTo(metersPerMile * 5, 0.01));
    });
  });
}
