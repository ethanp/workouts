import 'package:workouts/models/workout_exercise.dart';

class SetLogInput {
  const SetLogInput({
    this.weightKg,
    this.reps,
    this.duration,
    this.unitRemaining,
  });

  factory SetLogInput.fromPlan(
    PlannedSet? plannedSet,
    WorkoutExercise exercise,
  ) {
    return SetLogInput(
      weightKg: plannedSet?.weightKg,
      reps:
          plannedSet?.reps ??
          (exercise.modality == ExerciseModality.reps ? 1 : null),
      duration: plannedSet?.duration ?? exercise.workDuration,
      unitRemaining: plannedSet?.unitRemaining,
    );
  }

  final double? weightKg;
  final int? reps;
  final Duration? duration;
  final int? unitRemaining;
}
