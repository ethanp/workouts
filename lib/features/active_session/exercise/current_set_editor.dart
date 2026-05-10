import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/exercise/current_set_metric_tile.dart';
import 'package:workouts/features/active_session/exercise/current_set_planned_label.dart';
import 'package:workouts/features/active_session/exercise/current_set_value_stepper.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/weight.dart';
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
  late final TextEditingController _durationController;
  late final FocusNode _repsFocusNode;
  late final FocusNode _weightFocusNode;
  late final FocusNode _durationFocusNode;
  late final CurrentSetValueStepper _valueStepper;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(text: _initialRepsText);
    _weightController = TextEditingController(text: _initialWeightText);
    _durationController = TextEditingController(text: _initialDurationText);
    _repsFocusNode = FocusNode();
    _weightFocusNode = FocusNode();
    _durationFocusNode = FocusNode();
    _valueStepper = CurrentSetValueStepper(
      exercise: widget.exercise,
      repsController: _repsController,
      weightController: _weightController,
      durationController: _durationController,
      onChanged: _emitInput,
    );
    _repsFocusNode.addListener(_onFocusChanged);
    _weightFocusNode.addListener(_onFocusChanged);
    _durationFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _repsFocusNode.removeListener(_onFocusChanged);
    _weightFocusNode.removeListener(_onFocusChanged);
    _durationFocusNode.removeListener(_onFocusChanged);
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    _repsFocusNode.dispose();
    _weightFocusNode.dispose();
    _durationFocusNode.dispose();
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

  bool get _showsRepsControl => widget.exercise.setMetrics.tracksReps;

  bool get _showsWeightControl => widget.exercise.supportsAddedWeight;

  bool get _showsDurationControl => widget.exercise.setMetrics.tracksDuration;

  String get _initialWeightText {
    final weight = widget.initialInput.weight;
    if (weight == null) return '';
    return WeightDisplay.inputValue(weight, widget.exercise);
  }

  String get _initialDurationText {
    final duration = widget.initialInput.duration;
    if (duration == null) return '';
    return duration.inSeconds.toString();
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
    final inputTiles = <Widget>[];

    if (_showsRepsControl) {
      inputTiles.add(
        _metricTile(
          label: 'Reps',
          controller: _repsController,
          focusNode: _repsFocusNode,
          keyboardType: TextInputType.number,
          onDecrement: _valueStepper.decrementReps,
          onIncrement: _valueStepper.incrementReps,
        ),
      );
    }

    if (_showsWeightControl) {
      _addMetricGap(inputTiles);
      inputTiles.add(
        _metricTile(
          label: 'Weight',
          controller: _weightController,
          focusNode: _weightFocusNode,
          suffix: WeightDisplay.unitLabel(widget.exercise),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onDecrement: _valueStepper.decrementWeight,
          onIncrement: _valueStepper.incrementWeight,
        ),
      );
    }

    if (_showsDurationControl) {
      _addMetricGap(inputTiles);
      inputTiles.add(
        _metricTile(
          label: 'Time',
          controller: _durationController,
          focusNode: _durationFocusNode,
          suffix: 'sec',
          keyboardType: TextInputType.number,
          onDecrement: _valueStepper.decrementDuration,
          onIncrement: _valueStepper.incrementDuration,
        ),
      );
    }

    return Row(children: inputTiles);
  }

  void _addMetricGap(List<Widget> inputTiles) {
    if (inputTiles.isEmpty) return;
    inputTiles.add(const SizedBox(width: AppSpacing.sm));
  }

  Widget _metricTile({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputType keyboardType,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    String? suffix,
  }) {
    return Expanded(
      child: CurrentSetMetricTile(
        label: label,
        controller: controller,
        focusNode: focusNode,
        placeholder: '0',
        suffix: suffix,
        keyboardType: keyboardType,
        onChanged: (_) => _emitInput(),
        onDecrement: onDecrement,
        onIncrement: onIncrement,
      ),
    );
  }

  void _emitInput() {
    widget.onChanged(_input());
  }

  SetLogInput _input() {
    return SetLogInput(
      reps: _repsInput(),
      weight: _weightInput(),
      duration: _durationInput(),
      unitRemaining: widget.initialInput.unitRemaining,
    );
  }

  int? _repsInput() {
    if (!_showsRepsControl) return null;
    return int.tryParse(_repsController.text.trim());
  }

  Weight? _weightInput() {
    if (!_showsWeightControl) return null;
    return WeightDisplay.inputValueToWeight(
      _weightController.text,
      widget.exercise,
    );
  }

  Duration? _durationInput() {
    if (!_showsDurationControl) return null;
    final durationSeconds = int.tryParse(_durationController.text.trim());
    if (durationSeconds == null) return null;
    return Duration(seconds: durationSeconds);
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
