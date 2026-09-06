import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/active_session/exercise/current_set_metric_tile.dart';
import 'package:workouts/features/active_session/exercise/current_set_planned_label.dart';
import 'package:workouts/features/active_session/exercise/current_set_value_stepper.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

class const CurrentSetEditor({
  super.key,
  required final WorkoutExercise exercise,
  required final PlannedSet? plannedSet,
  required final SetLogInput initialInput,
  required final ValueChanged<SetLogInput> onChanged,

  /// 1-based index of the side currently being prepared for unilateral
  /// exercises. Drives the "Side N of 2" header annotation. Ignored when
  /// `exercise.isUnilateral` is false.
  final int currentSide = 1,
}) extends StatefulWidget {
  @override
  State<CurrentSetEditor> createState() => _CurrentSetEditorState();
}

class _CurrentSetEditorState() extends State<CurrentSetEditor> {
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
    _repsFocusNode.addListener(_rebuildForFocusChange);
    _weightFocusNode.addListener(_rebuildForFocusChange);
    _durationFocusNode.addListener(_rebuildForFocusChange);
  }

  @override
  void dispose() {
    _repsFocusNode.removeListener(_rebuildForFocusChange);
    _weightFocusNode.removeListener(_rebuildForFocusChange);
    _durationFocusNode.removeListener(_rebuildForFocusChange);
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
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: ELayout.spaceMd),
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
            _currentSetHeaderText,
            style: EText.caption.copyWith(
              color: EColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (plannedSetLabel != null) ...[
          const SizedBox(width: ELayout.spaceMd),
          Flexible(
            child: Text(
              plannedSetLabel,
              textAlign: TextAlign.end,
              style: EText.caption.copyWith(
                color: EColors.textMuted,
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
    inputTiles.add(const SizedBox(width: ELayout.spaceSm));
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

  void _rebuildForFocusChange() {
    if (!mounted) return;
    setState(() {});
  }

  String? get _plannedSetLabel {
    return CurrentSetPlannedLabel(
      plannedSet: widget.plannedSet,
      exercise: widget.exercise,
    ).text;
  }

  String get _currentSetHeaderText {
    if (!widget.exercise.isUnilateral) return 'Current set';
    return 'Current set · Side ${widget.currentSide} of '
        '${widget.exercise.sidesPerSet}';
  }
}
