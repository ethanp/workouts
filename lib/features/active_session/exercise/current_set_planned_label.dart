import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

class CurrentSetPlannedLabel {
  const CurrentSetPlannedLabel({
    required this.plannedSet,
    required this.exercise,
  });

  final PlannedSet? plannedSet;
  final WorkoutExercise exercise;

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
    return 'Planned ${plannedSetDetails.join(' @ ')}';
  }
}
