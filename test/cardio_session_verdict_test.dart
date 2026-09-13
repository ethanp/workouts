import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_session_verdict.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';

void main() {
  group('CardioSessionVerdict', () {
    test('calls mostly Z1–Z2 easy aerobic', () {
      final verdict = CardioSessionVerdict.fromWorkout(
        _workout(
          zoneTime: const HrZoneTime(zone1: 600, zone2: 1200, zone3: 120),
        ),
      );
      expect(verdict.aerobicJob, CardioAerobicJob.easyAerobic);
    });

    test('calls a mid-zone session steady aerobic', () {
      final verdict = CardioSessionVerdict.fromWorkout(
        _workout(
          zoneTime: const HrZoneTime(zone2: 400, zone3: 800, zone4: 100),
        ),
      );
      expect(verdict.aerobicJob, CardioAerobicJob.steadyAerobic);
    });

    test('calls meaningful Z4–Z5 hard aerobic', () {
      final verdict = CardioSessionVerdict.fromWorkout(
        _workout(
          zoneTime: const HrZoneTime(zone2: 300, zone4: 400, zone5: 200),
        ),
      );
      expect(verdict.aerobicJob, CardioAerobicJob.hardAerobic);
    });

    test('uses distance and pace for walks and treadmill runs', () {
      final walk = CardioSessionVerdict.fromWorkout(
        _workout(
          activityType: CardioType.outdoorWalk,
          distanceMeters: 3218.7,
          durationSeconds: 1800,
        ),
      );
      expect(walk.primaryWork.headline, contains('mi'));
      expect(walk.primaryWork.supporting, contains('/mi'));

      expect(CardioType.indoorWalk.primaryWork, CardioPrimaryWork.distanceAndPace);
      expect(CardioType.indoorRun.primaryWork, CardioPrimaryWork.distanceAndPace);
    });

    test('uses machine distance and METs for elliptical', () {
      final verdict = CardioSessionVerdict.fromWorkout(
        _workout(
          activityType: CardioType.elliptical,
          distanceMeters: 2400,
          averageMets: 7.6,
        ),
      );
      expect(verdict.primaryWork.headline, contains('mi'));
      expect(verdict.primaryWork.supporting, '7.6 METs');
    });

    test('uses flights and steps for stair climbing, never pace', () {
      final verdict = CardioSessionVerdict.fromWorkout(
        _workout(
          activityType: CardioType.stairClimbing,
          distanceMeters: 0,
          flightsClimbed: 18,
          stepCount: 2400,
        ),
      );
      expect(verdict.primaryWork.headline, '18 flights');
      expect(verdict.primaryWork.supporting, '2400 steps');
      expect(verdict.primaryWork.supporting, isNot(contains('/mi')));
    });

    test('has no aerobic job when zone time is missing', () {
      final verdict = CardioSessionVerdict.fromWorkout(_workout());
      expect(verdict.aerobicJob, CardioAerobicJob.unknown);
    });
  });
}

CardioWorkout _workout({
  CardioType activityType = CardioType.outdoorWalk,
  int durationSeconds = 1800,
  double distanceMeters = 0,
  HrZoneTime zoneTime = HrZoneTime.zero,
  double? averageMets,
  double? flightsClimbed,
  double? stepCount,
}) {
  return CardioWorkout(
    id: 'workout-1',
    externalWorkoutId: 'hk-1',
    activityType: activityType,
    startedAt: DateTime.utc(2026, 9, 1, 10),
    endedAt: DateTime.utc(2026, 9, 1, 10, 30),
    durationSeconds: durationSeconds,
    distanceMeters: distanceMeters,
    routeAvailable: activityType.hasRoute,
    sourceName: 'Apple Health',
    zoneTime: zoneTime,
    averageMets: averageMets,
    flightsClimbed: flightsClimbed,
    stepCount: stepCount,
  );
}
