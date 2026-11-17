import 'dart:math' as math;

import 'package:workouts/models/cardio_workout.dart';

class const SameTypeWorkoutComparison({
  required final CardioWorkout thisWorkout,
  required final List<CardioWorkout> peers,
}) {
  static const neighborsPerSide = 5;

  factory fromCatalog({
    required CardioWorkout thisWorkout,
    required List<CardioWorkout> catalog,
    int perSide = neighborsPerSide,
  }) {
    final sameType = [
      thisWorkout,
      for (final catalogWorkout in catalog)
        if (catalogWorkout.id != thisWorkout.id &&
            catalogWorkout.activityType == thisWorkout.activityType)
          catalogWorkout,
    ]..sort((first, second) => first.startedAt.compareTo(second.startedAt));
    final thisIndex = sameType.indexOf(thisWorkout);
    final availableBefore = thisIndex;
    final availableAfter = sameType.length - 1 - thisIndex;
    final takeBefore = math.min<int>(
      availableBefore,
      perSide + math.max<int>(0, perSide - availableAfter),
    );
    final takeAfter = math.min<int>(
      availableAfter,
      perSide + math.max<int>(0, perSide - availableBefore),
    );
    return SameTypeWorkoutComparison(
      thisWorkout: thisWorkout,
      peers: sameType.sublist(
        thisIndex - takeBefore,
        thisIndex + takeAfter + 1,
      ),
    );
  }

  bool get hasPeers => peers.length > 1;
}
