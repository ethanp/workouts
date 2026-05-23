import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/warmup_sets.dart';
import 'package:workouts/models/workout_exercise.dart';

class ExerciseSetPlanContext {
  const ExerciseSetPlanContext({required this.block, required this.exercise});

  final SessionBlock block;
  final WorkoutExercise exercise;

  List<SessionSetLog> get exerciseLogs => block.logs.whereL(
    (sessionSetLog) => sessionSetLog.exerciseId == exercise.id,
  );

  int get loggedSetCount => exerciseLogs.length;

  int get plannedSetCount => exercise.effectiveTargetSets;

  bool get isFullyLogged =>
      plannedSetCount > 0 && loggedSetCount >= plannedSetCount;

  /// The planned set definition for the next logged "side" of this exercise.
  /// Bilateral exercises (sidesPerSet = 1) map 1:1; unilateral exercises map
  /// every two logged sides back to the same underlying definition, so both
  /// sides of a 1x20s split squat hold draw their target from `plannedSets[0]`.
  PlannedSet? get nextPlannedSet {
    final int sideIndex = exerciseLogs.length;
    final int plannedSetIndex = sideIndex ~/ exercise.sidesPerSet;
    if (plannedSetIndex >= exercise.plannedSets.length) return null;
    return exercise.plannedSets[plannedSetIndex];
  }

  /// 1-based index of the side currently being prepared (1 for bilateral
  /// exercises, 1 or 2 for unilateral). Drives the "Side N of 2" caption.
  int get currentSideOfPair =>
      (exerciseLogs.length % exercise.sidesPerSet) + 1;

  Duration get setupDuration => exercise.setupDuration ?? Duration.zero;

  Duration get workDuration => exercise.workDuration ?? Duration.zero;

  Duration get restDuration => exercise.restDuration ?? Duration.zero;

  /// True when the exercise has setup or work phases that auto-flow when this
  /// is the next recommended exercise. Drives `ExerciseIntervalTimer`'s
  /// auto-start condition — rest does not count, since rest only starts
  /// after a set is logged.
  bool get hasSetupOrWorkTiming =>
      setupDuration > Duration.zero || workDuration > Duration.zero;

  /// True when the exercise has any timed phase (setup, work, or rest).
  /// Drives whether the timer panel is visible at all.
  bool get hasTiming =>
      hasSetupOrWorkTiming || restDuration > Duration.zero;

  bool get showsCurrentSetEditor {
    final PlannedSet? plannedSet = nextPlannedSet;
    return exercise.setMetrics.tracksReps ||
        exercise.setMetrics.supportsAddedWeight ||
        exercise.setMetrics.tracksDuration ||
        plannedSet?.reps != null ||
        plannedSet?.weight != null ||
        plannedSet?.duration != null;
  }

  bool get showsTimingWarning {
    return exercise.modality == ExerciseModality.timed &&
        exercise.prescription.contains('setup') &&
        !hasTiming;
  }

  String get setDraftKey => '${exercise.id}:$loggedSetCount';

  WarmupSets get warmupSets => WarmupSets(
    plannedSets: exercise.plannedSets,
    exercise: exercise,
    loggedSetCount: loggedSetCount,
  );

  SessionSetLog? get _mostRecentLog =>
      exerciseLogs.isEmpty ? null : exerciseLogs.last;

  SetLogInput get defaultSetLogInput => SetLogInput.forNextSet(
    exercise: exercise,
    plannedSet: nextPlannedSet,
    priorLog: _mostRecentLog,
  );
}
