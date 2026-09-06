import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

class const SetCaptureSheet({
  required final WorkoutExercise exercise,
  required final PlannedSet? plannedSet,
}) extends StatefulWidget {
  @override
  State<SetCaptureSheet> createState() => SetCaptureSheetState();
}

class SetCaptureSheetState() extends State<SetCaptureSheet> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final plannedSet = widget.plannedSet;
    _repsController = TextEditingController(
      text: (plannedSet?.reps ?? 1).toString(),
    );
    _weightController = TextEditingController(
      text: plannedSet?.weight == null
          ? ''
          : WeightDisplay.inputValue(plannedSet!.weight!, widget.exercise),
    );
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: ELayout.spaceLg,
        right: ELayout.spaceLg,
        top: ELayout.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + ELayout.spaceLg,
      ),
      decoration: const BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ELayout.radiusXl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: ELayout.spaceMd),
            _numberField(_repsController, 'Reps'),
            const SizedBox(height: ELayout.spaceSm),
            _numberField(
              _weightController,
              'Weight (${WeightDisplay.unitLabel(widget.exercise)})',
              decimal: true,
            ),
            const SizedBox(height: ELayout.spaceLg),
            _actions(context),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final plannedSet = widget.plannedSet;
    final typeLabel = plannedSet == null
        ? 'Set'
        : plannedSet.type.name.replaceFirst(
            plannedSet.type.name[0],
            plannedSet.type.name[0].toUpperCase(),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$typeLabel: ${widget.exercise.name}',
          style: EText.section,
        ),
        if (plannedSet != null) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text(
            'Planned ${_plannedSetLabel(plannedSet)}',
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String placeholder, {
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: EText.body.medium.copyWith(color: EColors.textPrimary),
      decoration: EInput.filledMd(hintText: placeholder),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: ELayout.spaceSm),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_input()),
            child: const Text('Log Set'),
          ),
        ),
      ],
    );
  }

  SetLogInput _input() {
    return SetLogInput(
      reps: int.tryParse(_repsController.text.trim()),
      weight: WeightDisplay.inputValueToWeight(
        _weightController.text,
        widget.exercise,
      ),
      duration: widget.plannedSet?.duration ?? widget.exercise.workDuration,
      unitRemaining: widget.plannedSet?.unitRemaining,
    );
  }

  String _plannedSetLabel(PlannedSet plannedSet) {
    final labelParts = <String>[];
    if (plannedSet.reps != null) labelParts.add('${plannedSet.reps} reps');
    if (plannedSet.weight != null) {
      labelParts.add(plannedSet.weight!.formatFor(widget.exercise));
    }
    if (plannedSet.duration != null) {
      labelParts.add('${plannedSet.duration!.inSeconds}s');
    }
    return labelParts.isEmpty ? 'set' : labelParts.join(' @ ');
  }
}
