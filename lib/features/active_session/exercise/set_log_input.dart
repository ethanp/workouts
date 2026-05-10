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
      weight: exercise.setMetrics.supportsAddedWeight
          ? plannedSet?.weight
          : null,
      reps: plannedSet?.reps ?? (exercise.setMetrics.tracksReps ? 1 : null),
      duration: exercise.setMetrics.tracksDuration
          ? plannedSet?.duration ?? exercise.workDuration
          : null,
      unitRemaining: plannedSet?.unitRemaining,
    );
  }

  final Weight? weight;
  final int? reps;
  final Duration? duration;
  final int? unitRemaining;
}
