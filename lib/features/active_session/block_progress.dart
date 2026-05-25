import 'package:collection/collection.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/early_stopped_notifier.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

/// Per-block view of which exercises are still pending vs. complete during
/// an active session. Exposes a per-exercise [ExerciseProgress] view so
/// callers stop reimplementing log-count + early-stopped checks in three
/// places.
///
/// Construct once per (block, earlyStopped) snapshot — the constructor
/// builds the count map eagerly. Cheap, but don't construct in a tight
/// inner loop if you can hoist it.
class BlockProgress {
  BlockProgress(SessionBlock block, EarlyStopped earlyStopped)
    : exerciseProgress = _build(block, earlyStopped);

  final List<ExerciseProgress> exerciseProgress;

  static List<ExerciseProgress> _build(
    SessionBlock block,
    EarlyStopped earlyStopped,
  ) {
    final logCounts = block.logs.countBy((log) => log.exerciseId);
    return [
      for (final exercise in block.exercises)
        ExerciseProgress._(
          exercise: exercise,
          blockId: block.id,
          loggedCount: logCounts[exercise.id] ?? 0,
          earlyStopped: earlyStopped,
        ),
    ];
  }

  /// First exercise in declared order that is not yet complete. Null when
  /// every exercise in the block is either fully logged, early-stopped, or
  /// has no scheduled sets.
  WorkoutExercise? firstUnfinishedExercise() => exerciseProgress
      .firstWhereOrNull((progress) => !progress.isComplete)
      ?.exercise;

  /// Every scheduled exercise in this block is complete. Blocks with no
  /// scheduled work also return true; pair with [hasScheduledWork] when
  /// you specifically want "complete and non-empty".
  bool get allComplete => firstUnfinishedExercise() == null;

  /// True when at least one exercise has effectiveTargetSets > 0 (real
  /// work to do). Decorative or zero-set entries don't count.
  bool get hasScheduledWork =>
      exerciseProgress.any((progress) => progress.hasScheduledWork);
}

/// Per-exercise slice of [BlockProgress]. Knows how many sets have been
/// logged for [exercise] and whether the user explicitly flagged it as
/// early-stopped, and answers the questions that derive from those two.
class ExerciseProgress {
  ExerciseProgress._({
    required this.exercise,
    required String blockId,
    required this.loggedCount,
    required EarlyStopped earlyStopped,
  }) : _blockId = blockId,
       _earlyStopped = earlyStopped;

  final WorkoutExercise exercise;
  final int loggedCount;
  final String _blockId;
  final EarlyStopped _earlyStopped;

  /// True when this exercise actually has scheduled sets to do.
  bool get hasScheduledWork => exercise.effectiveTargetSets > 0;

  /// True when there's nothing left for the user to do here: no scheduled
  /// sets, all sets logged, or the user said "I'm done with this one".
  bool get isComplete {
    if (loggedCount >= exercise.effectiveTargetSets) return true;
    return _earlyStopped.includes(
      blockId: _blockId,
      exerciseId: exercise.id,
    );
  }
}

/// Reactive [BlockProgress] for a given [SessionBlock]. Watches
/// [earlyStoppedProvider] under the hood so call sites never have to
/// thread an [EarlyStopped] around — they just `ref.watch(blockProgressProvider(block))`.
///
/// Auto-disposes when no listener remains; cached by SessionBlock value
/// equality (Freezed), so identical blocks across rebuilds reuse the
/// same instance until the block's logs/exercises actually change.
final blockProgressProvider =
    Provider.autoDispose.family<BlockProgress, SessionBlock>((ref, block) {
      final earlyStopped = ref.watch(earlyStoppedProvider);
      return BlockProgress(block, earlyStopped);
    });
