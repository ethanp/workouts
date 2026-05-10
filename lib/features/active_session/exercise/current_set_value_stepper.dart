import 'package:flutter/cupertino.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

class CurrentSetValueStepper {
  const CurrentSetValueStepper({
    required this.exercise,
    required this.repsController,
    required this.weightController,
    required this.onChanged,
  });

  final WorkoutExercise exercise;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final VoidCallback onChanged;

  void decrementReps() => _setReps(_decrementedReps);

  void incrementReps() => _setReps(_incrementedReps);

  void decrementWeight() => _setWeightText(_decrementedWeightText);

  void incrementWeight() => _setWeightText(_incrementedWeightText);

  int get _decrementedReps => (_repsValue - 1).clamp(0, 99).toInt();

  int get _incrementedReps => _repsValue + 1;

  String get _decrementedWeightText {
    final double adjustedWeight = _displayWeightValue - _weightStep;
    return _formatDisplayNumber(adjustedWeight < 0 ? 0 : adjustedWeight);
  }

  String get _incrementedWeightText =>
      _formatDisplayNumber(_displayWeightValue + _weightStep);

  int get _repsValue => int.tryParse(repsController.text.trim()) ?? 0;

  double get _displayWeightValue =>
      double.tryParse(weightController.text.trim()) ?? 0;

  double get _weightStep {
    final WeightUnit weightUnit = WeightDisplay.unitForExercise(exercise);
    if (weightUnit == WeightUnit.kilograms) return 1;
    return 5;
  }

  String _formatDisplayNumber(double displayNumber) {
    final double roundedDisplayNumber = displayNumber.roundToDouble();
    if ((displayNumber - roundedDisplayNumber).abs() < 0.0001) {
      return roundedDisplayNumber.round().toString();
    }
    return displayNumber.toStringAsFixed(1);
  }

  void _setReps(int reps) {
    _setControllerText(repsController, reps.toString());
    onChanged();
  }

  void _setWeightText(String weightText) {
    _setControllerText(weightController, weightText);
    onChanged();
  }

  void _setControllerText(TextEditingController controller, String text) {
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  }
}
