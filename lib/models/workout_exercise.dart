import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_exercise.freezed.dart';
part 'workout_exercise.g.dart';

enum ExerciseModality { reps, timed, hold, mobility, breath }

@freezed
class WorkoutExercise with _$WorkoutExercise {
  const factory WorkoutExercise({
    required String id,
    required String name,
    required ExerciseModality modality,
    required String prescription,
    @Default(1) int targetSets,
    String? equipment,
    String? cue,
  }) = _WorkoutExercise;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      _$WorkoutExerciseFromJson(json);
}
