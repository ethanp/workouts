import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';

void main() {
  test('includes this workout plus recent same-type peers only', () {
    final thisElliptical = _workout('this', CardioType.elliptical, 3);
    final comparison = SameTypeWorkoutComparison.fromCatalog(
      thisWorkout: thisElliptical,
      catalog: [
        _workout('newer-elliptical', CardioType.elliptical, 4),
        thisElliptical,
        _workout('walk', CardioType.outdoorWalk, 2),
        _workout('older-elliptical', CardioType.elliptical, 1),
      ],
    );

    expect(comparison.hasPeers, isTrue);
    expect(comparison.peers.map((peer) => peer.id), [
      'this',
      'newer-elliptical',
      'older-elliptical',
    ]);
  });

  test('omits the section when this type has no peers', () {
    final onlyWalk = _workout('only', CardioType.outdoorWalk, 1);
    final comparison = SameTypeWorkoutComparison.fromCatalog(
      thisWorkout: onlyWalk,
      catalog: [
        onlyWalk,
        _workout('elliptical', CardioType.elliptical, 2),
      ],
    );
    expect(comparison.hasPeers, isFalse);
  });
}

CardioWorkout _workout(String id, CardioType activityType, int day) {
  return CardioWorkout(
    id: id,
    externalWorkoutId: id,
    activityType: activityType,
    startedAt: DateTime.utc(2026, 9, day, 10),
    endedAt: DateTime.utc(2026, 9, day, 10, 30),
    durationSeconds: 1800,
    distanceMeters: 0,
    routeAvailable: activityType.hasRoute,
    sourceName: 'Apple Health',
  );
}
