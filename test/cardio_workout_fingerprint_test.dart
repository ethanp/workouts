import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_workout_fingerprint.dart';

void main() {
  final stored = CardioWorkoutFingerprint(
    externalWorkoutId: 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
    startedAt: DateTime.utc(2026, 3, 8, 14, 2, 11),
    endedAt: DateTime.utc(2026, 3, 8, 14, 48, 11),
    durationSeconds: 2760,
  );

  test('same Apple Health identity and times is unchanged', () {
    final fromHealthKit = CardioWorkoutFingerprint.fromHealthKitHeader({
      'externalWorkoutId': stored.externalWorkoutId.toLowerCase(),
      'startDate': '2026-03-08T14:02:11.000Z',
      'endDate': '2026-03-08T14:48:11.400Z',
      'durationSeconds': 2760,
    });
    expect(stored.matches(fromHealthKit), isTrue);
    expect(
      CardioWorkoutFingerprintIndex(
        fingerprints: [stored],
      ).containsUnchanged(fromHealthKit),
      isTrue,
    );
  });

  test('a longer or later workout must be fetched again', () {
    final longer = CardioWorkoutFingerprint(
      externalWorkoutId: stored.externalWorkoutId,
      startedAt: stored.startedAt,
      endedAt: stored.endedAt,
      durationSeconds: stored.durationSeconds + 30,
    );
    final later = CardioWorkoutFingerprint(
      externalWorkoutId: stored.externalWorkoutId,
      startedAt: stored.startedAt.add(const Duration(minutes: 5)),
      endedAt: stored.endedAt.add(const Duration(minutes: 5)),
      durationSeconds: stored.durationSeconds,
    );
    expect(stored.matches(longer), isFalse);
    expect(stored.matches(later), isFalse);
  });

  test('a different HealthKit UUID is new', () {
    expect(
      stored.matches(
        CardioWorkoutFingerprint(
          externalWorkoutId: '00000000-0000-0000-0000-000000000001',
          startedAt: stored.startedAt,
          endedAt: stored.endedAt,
          durationSeconds: stored.durationSeconds,
        ),
      ),
      isFalse,
    );
  });

  test('skip arguments carry the stored fingerprint for native matching', () {
    expect(stored.asHealthKitSkipArgument, {
      'externalWorkoutId': stored.externalWorkoutId,
      'startDate': '2026-03-08T14:02:11.000Z',
      'endDate': '2026-03-08T14:48:11.000Z',
      'durationSeconds': 2760,
    });
  });
}
