import 'package:workouts/models/session.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';

class SetLogInput {
  const SetLogInput({
    this.weight,
    this.reps,
    this.duration,
    this.unitRemaining,
  });

  /// Default editor values for the *next* set on an exercise.
  ///
  /// Strength fields (weight, reps) carry forward from [priorLog] when the
  /// user has already logged a set this block — once they've dialed in a
  /// real working weight or rep count, the next set should keep it instead
  /// of snapping back to the plan. Timing fields ([duration],
  /// [unitRemaining]) stay plan-driven: the user wants the next interval to
  /// start at the prescribed target, not "what was left when I stopped".
  factory SetLogInput.forNextSet({
    required WorkoutExercise exercise,
    PlannedSet? plannedSet,
    SessionSetLog? priorLog,
  }) {
    return SetLogInput(
      weight: exercise.setMetrics.supportsAddedWeight
          ? priorLog?.weight ?? plannedSet?.weight
          : null,
      reps: priorLog?.reps ??
          plannedSet?.reps ??
          (exercise.setMetrics.tracksReps ? 1 : null),
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
