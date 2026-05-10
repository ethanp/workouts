import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

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

  group('WeightDisplay', () {
    test('formats non-kettlebell weights in pounds', () {
      final exercise = _exercise(name: 'Chest Press Machine');

      expect(WeightDisplay.unitLabel(exercise), 'lb');
      expect(
        WeightDisplay.format(const Weight.kilograms(22.6796185), exercise),
        '50lb',
      );
      expect(
        WeightDisplay.inputValue(const Weight.kilograms(22.6796185), exercise),
        '50',
      );
      expect(
        WeightDisplay.inputValueToWeight('50', exercise)?.kilograms,
        closeTo(22.68, 0.01),
      );
    });

    test('formats kettlebell weights in kilograms', () {
      final exercise = _exercise(name: 'Kettlebell Swing');

      expect(WeightDisplay.unitLabel(exercise), 'kg');
      expect(
        WeightDisplay.format(const Weight.kilograms(20), exercise),
        '20kg',
      );
      expect(
        WeightDisplay.inputValue(const Weight.kilograms(20), exercise),
        '20',
      );
      expect(
        WeightDisplay.inputValueToWeight('20', exercise),
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
