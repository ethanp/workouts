import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/exercise_set_metrics.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/workout_exercise.dart';

void main() {
  group('LlmExercise.fromJson enum tolerance', () {
    test('falls back to reps when modality is an unknown value', () {
      final exercise = LlmExercise.fromJson({
        'name': 'Dead Hang',
        'prescription': '3 x 30s',
        'modality': 'durationOnly',
      });

      expect(exercise.modality, ExerciseModality.reps);
    });

    test('falls back to null when setMetricsStyle is an unknown value', () {
      final exercise = LlmExercise.fromJson({
        'name': 'Dead Hang',
        'prescription': '3 x 30s',
        'setMetricsStyle': 'reps',
      });

      expect(exercise.setMetricsStyle, isNull);
    });

    test('still parses valid enum values', () {
      final exercise = LlmExercise.fromJson({
        'name': 'Back Squat',
        'prescription': '3 x 5',
        'modality': 'reps',
        'setMetricsStyle': 'repsAndWeight',
      });

      expect(exercise.modality, ExerciseModality.reps);
      expect(exercise.setMetricsStyle, ExerciseSetMetricsStyle.repsAndWeight);
    });

    test('a block with one bad-modality exercise still parses all exercises', () {
      final block = LlmWorkoutBlock.fromJson({
        'title': 'Main',
        'type': 'strength',
        'estimatedMinutes': 20,
        'exercises': [
          {
            'name': 'Plank',
            'prescription': '3 x 45s',
            'modality': 'durationOnly',
          },
          {'name': 'Row', 'prescription': '3 x 10', 'modality': 'reps'},
        ],
      });

      expect(block.exercises, hasLength(2));
      expect(block.exercises.first.modality, ExerciseModality.reps);
    });
  });
}
