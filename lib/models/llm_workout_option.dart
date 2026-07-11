// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/exercise_set_metrics.dart';
import 'package:workouts/models/workout_exercise.dart';

part 'llm_workout_option.freezed.dart';
part 'llm_workout_option.g.dart';

@freezed
abstract class LlmWorkoutOption with _$LlmWorkoutOption {
  const factory LlmWorkoutOption({
    required String id,
    required String title,
    required String goal,
    required String rationale,
    required List<LlmWorkoutBlock> blocks,
  }) = _LlmWorkoutOption;

  factory LlmWorkoutOption.fromJson(Map<String, dynamic> json) =>
      _$LlmWorkoutOptionFromJson(json);
}

@freezed
abstract class LlmWorkoutBlock with _$LlmWorkoutBlock {
  const factory LlmWorkoutBlock({
    required String title,
    required String type,
    required int estimatedMinutes,
    required List<LlmExercise> exercises,
    String? description,
    @Default(1) int rounds,
  }) = _LlmWorkoutBlock;

  factory LlmWorkoutBlock.fromJson(Map<String, dynamic> json) =>
      _$LlmWorkoutBlockFromJson(json);
}

@freezed
abstract class LlmExercise with _$LlmExercise {
  const factory LlmExercise({
    required String name,
    required String prescription,
    @JsonKey(unknownEnumValue: ExerciseModality.reps)
    @Default(ExerciseModality.reps)
    ExerciseModality modality,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    ExerciseSetMetricsStyle? setMetricsStyle,
    @Default([]) List<PlannedSet> plannedSets,
    int? restSeconds,
    String? notes,
    @Default(false) bool isUnilateral,
  }) = _LlmExercise;

  factory LlmExercise.fromJson(Map<String, dynamic> json) =>
      _$LlmExerciseFromJson(json);
}

@freezed
abstract class LlmWorkoutResponse with _$LlmWorkoutResponse {
  const factory LlmWorkoutResponse({
    required List<LlmWorkoutOption> options,
    required String explanation,
  }) = _LlmWorkoutResponse;

  factory LlmWorkoutResponse.fromJson(Map<String, dynamic> json) =>
      _$LlmWorkoutResponseFromJson(json);
}
