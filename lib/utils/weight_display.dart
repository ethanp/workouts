import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';

class WeightDisplay {
  const WeightDisplay._();

  static WeightUnit unitForExercise(WorkoutExercise exercise) {
    final exerciseText = '${exercise.name} ${exercise.equipment ?? ''}'
        .toLowerCase();
    if (exerciseText.contains('kettlebell') || exerciseText.contains('kb')) {
      return WeightUnit.kilograms;
    }
    return WeightUnit.pounds;
  }

  static String unitLabel(WorkoutExercise exercise) {
    return unitForExercise(exercise).label;
  }

  static String format(Weight weight, WorkoutExercise exercise) {
    return weight.format(unitForExercise(exercise));
  }

  static String inputValue(Weight weight, WorkoutExercise exercise) {
    return weight.inputValue(unitForExercise(exercise));
  }

  static Weight? inputValueToWeight(String input, WorkoutExercise exercise) {
    return Weight.fromInput(input, unitForExercise(exercise));
  }
}
