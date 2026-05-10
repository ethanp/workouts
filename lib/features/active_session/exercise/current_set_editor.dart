import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/exercise/current_set_metric_tile.dart';
import 'package:workouts/features/active_session/exercise/current_set_planned_label.dart';
import 'package:workouts/features/active_session/exercise/current_set_value_stepper.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/weight_display.dart';

class CurrentSetEditor extends StatefulWidget {
  const CurrentSetEditor({
    super.key,
    required this.exercise,
    required this.plannedSet,
    required this.initialInput,
    required this.onChanged,
  });

  final WorkoutExercise exercise;
  final PlannedSet? plannedSet;
  final SetLogInput initialInput;
  final ValueChanged<SetLogInput> onChanged;

  @override
  State<CurrentSetEditor> createState() => _CurrentSetEditorState();
}

class _CurrentSetEditorState extends State<CurrentSetEditor> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final FocusNode _repsFocusNode;
  late final FocusNode _weightFocusNode;
  late final CurrentSetValueStepper _valueStepper;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(text: _initialRepsText);
    _weightController = TextEditingController(text: _initialWeightText);
    _repsFocusNode = FocusNode();
    _weightFocusNode = FocusNode();
    _valueStepper = CurrentSetValueStepper(
      exercise: widget.exercise,
      repsController: _repsController,
      weightController: _weightController,
      onChanged: _emitInput,
    );
    _repsFocusNode.addListener(_onFocusChanged);
    _weightFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _repsFocusNode.removeListener(_onFocusChanged);
    _weightFocusNode.removeListener(_onFocusChanged);
    _repsController.dispose();
    _weightController.dispose();
    _repsFocusNode.dispose();
    _weightFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          _inputTiles(),
        ],
      ),
    );
  }

  String get _initialRepsText => widget.initialInput.reps?.toString() ?? '';

  String get _initialWeightText {
    final weight = widget.initialInput.weight;
    if (weight == null) return '';
    return WeightDisplay.inputValue(weight, widget.exercise);
  }

  Widget _header() {
    final String? plannedSetLabel = _plannedSetLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Current set',
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (plannedSetLabel != null) ...[
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              plannedSetLabel,
              textAlign: TextAlign.end,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _inputTiles() {
    return Row(
      children: [
        Expanded(
          child: CurrentSetMetricTile(
            label: 'Reps',
            controller: _repsController,
            focusNode: _repsFocusNode,
            placeholder: '0',
            keyboardType: TextInputType.number,
            onChanged: (_) => _emitInput(),
            onDecrement: _valueStepper.decrementReps,
            onIncrement: _valueStepper.incrementReps,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: CurrentSetMetricTile(
            label: 'Weight',
            controller: _weightController,
            focusNode: _weightFocusNode,
            placeholder: '0',
            suffix: WeightDisplay.unitLabel(widget.exercise),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: (_) => _emitInput(),
            onDecrement: _valueStepper.decrementWeight,
            onIncrement: _valueStepper.incrementWeight,
          ),
        ),
      ],
    );
  }

  void _emitInput() {
    widget.onChanged(_input());
  }

  SetLogInput _input() {
    return SetLogInput(
      reps: int.tryParse(_repsController.text.trim()),
      weight: WeightDisplay.inputValueToWeight(
        _weightController.text,
        widget.exercise,
      ),
      duration: widget.initialInput.duration,
      unitRemaining: widget.initialInput.unitRemaining,
    );
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String? get _plannedSetLabel {
    return CurrentSetPlannedLabel(
      plannedSet: widget.plannedSet,
      exercise: widget.exercise,
    ).text;
  }
}
