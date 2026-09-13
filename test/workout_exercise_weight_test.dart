import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';

void main() {
  group('Weight', () {
    test('stores kilograms and converts to pounds', () {
      const weight = Weight.kilograms(22.6796185);

      expect(weight.kilograms, closeTo(22.68, 0.01));
      expect(weight.pounds, closeTo(50, 0.01));
      expect(weight.formatPounds(), '50lb');
      expect(weight.formatKilograms(), '22.7kg');
    });
  });

  group('WorkoutExercise.weightUnit', () {
    test('formats non-kettlebell weights in pounds', () {
      final exercise = _exercise(name: 'Chest Press Machine');

      expect(exercise.weightUnit, WeightUnit.pounds);
      expect(exercise.weightUnit.label, 'lb');
      expect(const Weight.kilograms(22.6796185).formatFor(exercise), '50lb');
      expect(
        const Weight.kilograms(22.6796185).inputValue(exercise.weightUnit),
        '50',
      );
      expect(
        Weight.fromInput('50', exercise.weightUnit)?.kilograms,
        closeTo(22.68, 0.01),
      );
    });

    test('formats kettlebell weights in kilograms', () {
      final exercise = _exercise(name: 'Kettlebell Swing');

      expect(exercise.weightUnit, WeightUnit.kilograms);
      expect(exercise.weightUnit.label, 'kg');
      expect(const Weight.kilograms(20).formatFor(exercise), '20kg');
      expect(const Weight.kilograms(20).inputValue(exercise.weightUnit), '20');
      expect(
        Weight.fromInput('20', exercise.weightUnit),
        const Weight.kilograms(20),
      );
    });
  });
}

WorkoutExercise _exercise({required String name, String? equipment}) {
  return WorkoutExercise(
    id: name,
    name: name,
    modality: ExerciseModality.reps,
    prescription: '',
    equipment: equipment,
  );
}
