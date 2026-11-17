import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';

void main() {
  test('includes same-type peers only, oldest first', () {
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
      'older-elliptical',
      'this',
      'newer-elliptical',
    ]);
  });

  test('omits the section when this type has no peers', () {
    final onlyWalk = _workout('only', CardioType.outdoorWalk, 1);
    final comparison = SameTypeWorkoutComparison.fromCatalog(
      thisWorkout: onlyWalk,
      catalog: [onlyWalk, _workout('elliptical', CardioType.elliptical, 2)],
    );
    expect(comparison.hasPeers, isFalse);
  });

  test('takes five on each side when both sides have room', () {
    final comparison = _comparisonAtDay(15, totalDays: 30);
    expect(_days(comparison), [for (var day = 10; day <= 20; day++) day]);
  });

  test('extends to ten before when this is the newest', () {
    final comparison = _comparisonAtDay(30, totalDays: 30);
    expect(_days(comparison), [for (var day = 20; day <= 30; day++) day]);
  });

  test('extends to ten after when this is the oldest', () {
    final comparison = _comparisonAtDay(1, totalDays: 30);
    expect(_days(comparison), [for (var day = 1; day <= 11; day++) day]);
  });

  test('borrows only the shortfall from the far side', () {
    final comparison = _comparisonAtDay(28, totalDays: 30);
    expect(_days(comparison), [for (var day = 20; day <= 30; day++) day]);
  });

  test('keeps everything when fewer than ten neighbors exist', () {
    final comparison = _comparisonAtDay(2, totalDays: 6);
    expect(_days(comparison), [1, 2, 3, 4, 5, 6]);
  });

  test('includes this workout when the catalog has not loaded it', () {
    final thisRide = _workout('this', CardioType.indoorCycle, 5);
    final comparison = SameTypeWorkoutComparison.fromCatalog(
      thisWorkout: thisRide,
      catalog: [_workout('older', CardioType.indoorCycle, 1)],
    );
    expect(comparison.peers.map((peer) => peer.id), ['older', 'this']);
  });
}

SameTypeWorkoutComparison _comparisonAtDay(int day, {required int totalDays}) {
  final catalog = [
    for (var catalogDay = totalDays; catalogDay >= 1; catalogDay--)
      _workout('day-$catalogDay', CardioType.indoorCycle, catalogDay),
  ];
  return SameTypeWorkoutComparison.fromCatalog(
    thisWorkout: catalog.firstWhere((workout) => workout.id == 'day-$day'),
    catalog: catalog,
  );
}

List<int> _days(SameTypeWorkoutComparison comparison) =>
    comparison.peers.map((peer) => peer.startedAt.day).toList();

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
