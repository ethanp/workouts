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

  /// Identity-only projection of `exercises` for filtering by id.
  Set<String> get exerciseIds =>
      exercises.map((exercise) => exercise.id).toSet();
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

  /// Looks up a block by id. Throws when not found rather than returning
  /// null because every existing caller depends on the block being present
  /// (the id came from this session in the first place); a missing block is
  /// a programmer error worth surfacing loudly.
  SessionBlock blockById(String blockId) => blocks.firstWhere(
    (block) => block.id == blockId,
    orElse: () =>
        throw StateError('Block $blockId not found in session $id'),
  );
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
