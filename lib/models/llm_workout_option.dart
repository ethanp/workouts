import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_workout_option.freezed.dart';
part 'llm_workout_option.g.dart';

@freezed
abstract class LlmWorkoutOption with _$LlmWorkoutOption {
  const factory LlmWorkoutOption({
    required String id,
    required String title,
    required int estimatedMinutes,
    required String rationale,
    required List<LlmExercise> exercises,
  }) = _LlmWorkoutOption;

  factory LlmWorkoutOption.fromJson(Map<String, dynamic> json) =>
      _$LlmWorkoutOptionFromJson(json);
}

@freezed
abstract class LlmExercise with _$LlmExercise {
  const factory LlmExercise({
    required String name,
    String? sets,
    String? reps,
    String? duration,
    String? notes,
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
