import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

class ExerciseSetPlanContext {
  const ExerciseSetPlanContext({
    required this.block,
    required this.exercise,
  });

  final SessionBlock block;
  final WorkoutExercise exercise;

  List<SessionSetLog> get exerciseLogs =>
      block.logs
          .whereL((sessionSetLog) => sessionSetLog.exerciseId == exercise.id);

  int get loggedSetCount => exerciseLogs.length;

  int get plannedSetCount => exercise.effectiveTargetSets;

  PlannedSet? get nextPlannedSet {
    final int setIndex = exerciseLogs.length;
    if (setIndex >= exercise.plannedSets.length) return null;
    return exercise.plannedSets[setIndex];
  }

  bool get hasTiming =>
      setupDuration > Duration.zero || workDuration > Duration.zero;

  Duration get setupDuration => exercise.setupDuration ?? Duration.zero;

  Duration get workDuration => exercise.workDuration ?? Duration.zero;

  bool get showsCurrentSetEditor {
    final PlannedSet? plannedSet = nextPlannedSet;
    return exercise.modality == ExerciseModality.reps ||
        plannedSet?.reps != null ||
        plannedSet?.weight != null;
  }

  bool get showsTimingWarning {
    return exercise.modality == ExerciseModality.timed &&
        exercise.prescription.contains('setup') &&
        !hasTiming;
  }

  String get setDraftKey => '${exercise.id}:$loggedSetCount';

  SetLogInput get defaultSetLogInput {
    return SetLogInput.fromPlan(nextPlannedSet, exercise);
  }
}
