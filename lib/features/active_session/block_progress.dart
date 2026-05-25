import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/early_stopped_notifier.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

/// Per-block view of "what's still pending vs. accounted for" during an
/// active session. Owns the per-exercise log count map and the
/// "complete-or-early-stopped" predicate so callers stop reimplementing
/// that loop in three places.
///
/// Construct once per (block, earlyStopped) snapshot — the constructor
/// builds the count map eagerly. Cheap, but don't construct in a tight
/// inner loop if you can hoist it.
class BlockProgress {
  BlockProgress(this._block, this._earlyStopped)
    : _logCounts = _buildLogCounts(_block);

  final SessionBlock _block;
  final Set<String> _earlyStopped;
  final Map<String, int> _logCounts;

  static Map<String, int> _buildLogCounts(SessionBlock block) {
    final counts = <String, int>{};
    for (final log in block.logs) {
      counts.update(
        log.exerciseId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  int loggedCountFor(WorkoutExercise exercise) =>
      _logCounts[exercise.id] ?? 0;

  /// True when [exercise] either has no scheduled sets, has all of its
  /// sets logged, or is marked early-stopped.
  bool isAccountedFor(WorkoutExercise exercise) {
    final targetSets = exercise.effectiveTargetSets;
    if (targetSets <= 0) return true;
    if (loggedCountFor(exercise) >= targetSets) return true;
    return _earlyStopped.contains(
      earlyStoppedKey(blockId: _block.id, exerciseId: exercise.id),
    );
  }

  /// First exercise in declared order with effectiveTargetSets > 0 that
  /// is neither fully logged nor early-stopped. Null when there's no
  /// scheduled work left.
  WorkoutExercise? firstUnfinishedExercise() {
    for (final exercise in _block.exercises) {
      if (exercise.effectiveTargetSets <= 0) continue;
      if (isAccountedFor(exercise)) continue;
      return exercise;
    }
    return null;
  }

  /// Every scheduled exercise is either fully logged or early-stopped.
  /// Note: a block with no scheduled exercises (effectiveTargetSets <= 0
  /// for all) also returns true here. Pair with [hasScheduledWork] when
  /// you specifically want "complete and non-empty".
  bool get isComplete => firstUnfinishedExercise() == null;

  /// True when at least one exercise in this block has effectiveTargetSets
  /// > 0 (i.e. there is real work for the user to do). Decorative or
  /// zero-set entries don't count.
  bool get hasScheduledWork =>
      _block.exercises.any((exercise) => exercise.effectiveTargetSets > 0);
}

/// Reactive [BlockProgress] for a given [SessionBlock]. Watches
/// [earlyStoppedProvider] under the hood so call sites never have to
/// thread `Set<String>` around — they just `ref.watch(blockProgressProvider(block))`.
///
/// Auto-disposes when no listener remains; cached by SessionBlock value
/// equality (Freezed), so identical blocks across rebuilds reuse the
/// same instance until the block's logs/exercises actually change.
final blockProgressProvider =
    Provider.autoDispose.family<BlockProgress, SessionBlock>((ref, block) {
      final earlyStopped = ref.watch(earlyStoppedProvider);
      return BlockProgress(block, earlyStopped);
    });
