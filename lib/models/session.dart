// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/json_converters.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
abstract class SessionSetLog with _$SessionSetLog {
  const factory SessionSetLog({
    required String id,
    required String sessionBlockId,
    required String exerciseId,
    required int setIndex,
    @JsonKey(name: 'weightKg')
    @NullableWeightKilogramsConverter()
    Weight? weight,
    int? reps,
    @NullableDurationSecondsConverter() Duration? duration,
    int? unitRemaining,
  }) = _SessionSetLog;

  const SessionSetLog._();

  factory SessionSetLog.fromJson(Map<String, dynamic> json) =>
      _$SessionSetLogFromJson(json);
}

@freezed
abstract class SessionBlock with _$SessionBlock {
  const factory SessionBlock({
    required String id,
    required String sessionId,
    required WorkoutBlockType type,
    required int blockIndex,
    required List<WorkoutExercise> exercises,
    required List<SessionSetLog> logs,
    @DurationSecondsConverter() required Duration targetDuration,
    @NullableDurationSecondsConverter() Duration? actualDuration,
    String? notes,
    int? roundIndex,
    int? totalRounds,
  }) = _SessionBlock;

  const SessionBlock._();

  factory SessionBlock.fromJson(Map<String, dynamic> json) =>
      _$SessionBlockFromJson(json);

  WorkoutExercise? get nextIncompleteExercise {
    final counts = <String, int>{};
    for (final log in logs) {
      counts.update(log.exerciseId, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final exercise in exercises) {
      final targetSets = exercise.effectiveTargetSets;
      if (targetSets <= 0) {
        continue;
      }
      final completed = counts[exercise.id] ?? 0;
      if (completed < targetSets) {
        return exercise;
      }
    }
    return null;
  }
}

@freezed
abstract class Session with _$Session {
  const factory Session({
    required String id,
    required String templateId,
    required DateTime startedAt,
    DateTime? completedAt,
    @NullableDurationSecondsConverter() Duration? duration,
    String? notes,
    String? feeling,
    int? averageHeartRate,
    int? maxHeartRate,
    required List<SessionBlock> blocks,
    @Default(false) bool isPaused,
    DateTime? pausedAt,
    @Default(Duration.zero)
    @DurationSecondsConverter()
    Duration totalPausedDuration,
    DateTime? updatedAt,
  }) = _Session;

  const Session._();

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}

/// Derives which fitness goals a session covers based on the benefits
/// annotated on its exercises. Used by the Training Balance Strip.
extension SessionComposition on Session {
  Set<String> get coveredGoalIds => blocks
      .expand((block) => block.exercises)
      .expand((exercise) => exercise.benefits)
      .expand((benefit) => benefit.goalIds)
      .toSet();

  bool coversGoal(String goalId) => coveredGoalIds.contains(goalId);
}

/// Helpers for reasoning about exercise placement across multi-round sibling
/// blocks (blocks of the same `type` and `totalRounds`). Mid-session
/// add/remove/replace mutations propagate across these siblings; UIs that
/// confirm such mutations need the same view of "how much would change?".
extension SessionExerciseImpact on Session {
  /// IDs of every block that mirrors changes made to [target]: the target
  /// itself when not part of a multi-round set, otherwise every block
  /// sharing its `type` and `totalRounds`.
  Set<String> siblingBlockIdsOf(SessionBlock target) {
    if (target.totalRounds == null) return {target.id};
    return blocks
        .where(
          (block) =>
              block.type == target.type &&
              block.totalRounds == target.totalRounds,
        )
        .map((block) => block.id)
        .toSet();
  }

  /// Number of blocks that would be affected by mutating [target] — i.e. the
  /// size of the sibling set, including [target] itself.
  int siblingBlockCountOf(SessionBlock target) =>
      siblingBlockIdsOf(target).length;

  /// Total logged sets attributed to [exerciseId] across [target] and all of
  /// its sibling blocks.
  int loggedSetCountForExerciseAcrossSiblings({
    required SessionBlock target,
    required String exerciseId,
  }) {
    final siblingIds = siblingBlockIdsOf(target);
    return blocks
        .where((block) => siblingIds.contains(block.id))
        .expand((block) => block.logs)
        .where((log) => log.exerciseId == exerciseId)
        .length;
  }
}
