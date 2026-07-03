import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_import_payload.dart';
import 'package:workouts/models/cardio_type.dart';

void main() {
  group('CardioImportPayload.tryParse', () {
    test('accepts numeric values from native payloads in common shapes', () {
      final payload = CardioImportPayload.tryParse({
        'externalWorkoutId': 'workout-1',
        'activityType': 'elliptical',
        'startDate': '2026-05-09T10:00:00Z',
        'endDate': '2026-05-09T10:30:00Z',
        'durationSeconds': '1800',
        'distanceMeters': 1200,
        'energyKcal': '150.5',
        'avgHeartRateBpm': 125.2,
        'maxHeartRateBpm': '155',
        'routeAvailable': true,
        'sourceName': 'Apple Health',
        'routePoints': [
          {
            'lat': '30.1',
            'lng': -97.7,
            'altitudeMeters': '12.5',
            'timestamp': '2026-05-09T10:00:00Z',
          },
          {'lat': null, 'lng': -97.8},
        ],
        'heartRateSeries': [
          {'timestamp': '2026-05-09T10:00:01Z', 'bpm': '124.6'},
          {'timestamp': null, 'bpm': 130},
        ],
      });

      expect(payload, isNotNull);
      expect(payload!.activityType, CardioType.elliptical);
      expect(payload.durationSeconds, 1800);
      expect(payload.distanceMeters, 1200);
      expect(payload.energyKcal, 150.5);
      expect(payload.maxHeartRateBpm, 155);
      expect(payload.routePoints, hasLength(1));
      expect(payload.heartRateSamples.single.bpm, 125);
    });

    test('maps the indoor walk activity type with distance and no route', () {
      final indoorWalk = CardioImportPayload.tryParse({
        'externalWorkoutId': 'walk-indoor',
        'activityType': 'indoorWalk',
        'startDate': '2026-05-09T10:00:00Z',
        'endDate': '2026-05-09T10:30:00Z',
        'durationSeconds': 1800,
        'distanceMeters': 1600,
      });

      expect(indoorWalk!.activityType, CardioType.indoorWalk);
      expect(indoorWalk.activityType.hasDistance, isTrue);
      expect(indoorWalk.activityType.hasRoute, isFalse);
      expect(indoorWalk.distanceMeters, 1600);
    });

    test('returns null when required identifiers are missing', () {
      expect(CardioImportPayload.tryParse({'startDate': 'x'}), isNull);
    });
  });
}
