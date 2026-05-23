// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:workouts/models/workout_exercise.dart';

part 'exercise_replacement_suggestion.freezed.dart';
part 'exercise_replacement_suggestion.g.dart';

/// A single AI-suggested alternative to an in-session exercise.
///
/// [exercise] is always a fully-formed [WorkoutExercise] — the picker hands
/// this directly to the session replace flow. [isFromLibrary] tells the
/// caller whether the underlying row already exists in the user's library
/// (in which case [exercise.id] is canonical) or whether the AI proposed a
/// brand-new movement (in which case the id is freshly minted and the
/// session store will upsert it on commit).
@freezed
abstract class ExerciseReplacementSuggestion
    with _$ExerciseReplacementSuggestion {
  const factory ExerciseReplacementSuggestion({
    required WorkoutExercise exercise,
    required String reason,
    required bool isFromLibrary,
  }) = _ExerciseReplacementSuggestion;

  factory ExerciseReplacementSuggestion.fromJson(Map<String, dynamic> json) =>
      _$ExerciseReplacementSuggestionFromJson(json);
}
