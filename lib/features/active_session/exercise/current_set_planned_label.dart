import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

class const CurrentSetPlannedLabel({
  required final PlannedSet? plannedSet,
  required final WorkoutExercise exercise,
}) {
  String? get text {
    final PlannedSet? currentPlannedSet = plannedSet;
    if (currentPlannedSet == null) return null;

    final plannedSetDetails = <String>[];
    if (currentPlannedSet.reps != null) {
      plannedSetDetails.add('${currentPlannedSet.reps} reps');
    }
    if (currentPlannedSet.weight != null) {
      plannedSetDetails.add(currentPlannedSet.weight!.formatFor(exercise));
    }
    if (currentPlannedSet.duration != null) {
      plannedSetDetails.add('${currentPlannedSet.duration!.inSeconds}s');
    }
    if (plannedSetDetails.isEmpty) return null;
    final base = 'Planned ${plannedSetDetails.join(' @ ')}';
    final intensity = currentPlannedSet.targetIntensity;
    if (intensity == null || intensity.isEmpty) return base;
    return '$base, $intensity';
  }
}
