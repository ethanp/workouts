import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';

class SetLogInput {
  const SetLogInput({
    this.weight,
    this.reps,
    this.duration,
    this.unitRemaining,
  });

  factory SetLogInput.fromPlan(
    PlannedSet? plannedSet,
    WorkoutExercise exercise,
  ) {
    return SetLogInput(
      weight: plannedSet?.weight,
      reps:
          plannedSet?.reps ??
          (exercise.modality == ExerciseModality.reps ? 1 : null),
      duration: plannedSet?.duration ?? exercise.workDuration,
      unitRemaining: plannedSet?.unitRemaining,
    );
  }

  final Weight? weight;
  final int? reps;
  final Duration? duration;
  final int? unitRemaining;
}
