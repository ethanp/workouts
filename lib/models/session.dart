import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/json_converters.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
class SessionSetLog with _$SessionSetLog {
  const factory SessionSetLog({
    required String id,
    required String sessionBlockId,
    required String exerciseId,
    required int setIndex,
    double? weightKg,
    int? reps,
    @NullableDurationSecondsConverter() Duration? duration,
    double? rpe,
    String? notes,
  }) = _SessionSetLog;

  factory SessionSetLog.fromJson(Map<String, dynamic> json) =>
      _$SessionSetLogFromJson(json);
}

@freezed
class SessionBlock with _$SessionBlock {
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

  factory SessionBlock.fromJson(Map<String, dynamic> json) =>
      _$SessionBlockFromJson(json);
}

@freezed
class BreathSegment with _$BreathSegment {
  const factory BreathSegment({
    required String id,
    required String sessionId,
    required String pattern,
    @DurationSecondsConverter() required Duration targetDuration,
    @NullableDurationSecondsConverter() Duration? actualDuration,
  }) = _BreathSegment;

  factory BreathSegment.fromJson(Map<String, dynamic> json) =>
      _$BreathSegmentFromJson(json);
}

@freezed
class Session with _$Session {
  const factory Session({
    required String id,
    required String templateId,
    required DateTime startedAt,
    DateTime? completedAt,
    @NullableDurationSecondsConverter() Duration? duration,
    String? notes,
    String? feeling,
    required List<SessionBlock> blocks,
    required List<BreathSegment> breathSegments,
    @Default(false) bool isPaused,
    DateTime? pausedAt,
    @Default(Duration.zero)
    @DurationSecondsConverter()
    Duration totalPausedDuration,
    DateTime? updatedAt,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}

extension SessionBlockRecommendations on SessionBlock {
  WorkoutExercise? get nextIncompleteExercise {
    final counts = <String, int>{};
    for (final log in logs) {
      counts.update(log.exerciseId, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final exercise in exercises) {
      final targetSets = exercise.targetSets;
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
