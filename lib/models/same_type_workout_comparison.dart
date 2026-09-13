import 'package:workouts/models/cardio_workout.dart';

class const SameTypeWorkoutComparison({
  required final CardioWorkout thisWorkout,
  required final List<CardioWorkout> peers,
}) {
  factory fromCatalog({
    required CardioWorkout thisWorkout,
    required List<CardioWorkout> catalog,
    int peerLimit = 6,
  }) {
    final otherSameType = <CardioWorkout>[];
    for (final catalogWorkout in catalog) {
      if (catalogWorkout.id == thisWorkout.id) continue;
      if (catalogWorkout.activityType != thisWorkout.activityType) continue;
      otherSameType.add(catalogWorkout);
      if (otherSameType.length >= peerLimit - 1) break;
    }
    return SameTypeWorkoutComparison(
      thisWorkout: thisWorkout,
      peers: [thisWorkout, ...otherSameType],
    );
  }

  bool get hasPeers => peers.length > 1;
}
