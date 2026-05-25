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
  /// Once the user has dialed in real values for a set, the next set
  /// defaults to those rather than snapping back to the plan — applies to
  /// every numeric field the editor exposes (weight, reps, duration). The
  /// only field that stays plan-driven is [unitRemaining], which is a
  /// rep-style countdown read off the prescription, not something the user
  /// adjusts per-set.
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
          ? priorLog?.duration ??
              plannedSet?.duration ??
              exercise.workDuration
          : null,
      unitRemaining: plannedSet?.unitRemaining,
    );
  }

  final Weight? weight;
  final int? reps;
  final Duration? duration;
  final int? unitRemaining;
}
