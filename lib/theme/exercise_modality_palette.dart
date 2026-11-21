import 'package:ethan_ui/ethan_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:workouts/models/workout_exercise.dart';

extension ExerciseModalityColor on ExerciseModality {
  Color get color => switch (this) {
    ExerciseModality.reps => EColors.accent,
    ExerciseModality.timed => EColors.warning,
    ExerciseModality.hold => EColors.warning,
    ExerciseModality.mobility => EColors.success,
    ExerciseModality.breath => EColors.textTertiary,
  };
}
