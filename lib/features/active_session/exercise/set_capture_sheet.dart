import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';

class SetCaptureSheet extends StatefulWidget {
  const SetCaptureSheet({required this.exercise, required this.plannedSet});

  final WorkoutExercise exercise;
  final PlannedSet? plannedSet;

  @override
  State<SetCaptureSheet> createState() => SetCaptureSheetState();
}

class SetCaptureSheetState extends State<SetCaptureSheet> {
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
      text: plannedSet?.weightKg == null
          ? ''
          : _formatWeight(plannedSet!.weightKg!),
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
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: AppSpacing.md),
            _numberField(_repsController, 'Reps'),
            const SizedBox(height: AppSpacing.sm),
            _numberField(_weightController, 'Weight (kg)', decimal: true),
            const SizedBox(height: AppSpacing.lg),
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
          style: AppTypography.subtitle,
        ),
        if (plannedSet != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Planned ${_plannedSetLabel(plannedSet)}',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
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
    return CupertinoTextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      placeholder: placeholder,
      placeholderStyle: AppTypography.body.copyWith(
        color: AppColors.textColor4,
      ),
      style: AppTypography.body.copyWith(color: AppColors.textColor1),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            color: AppColors.backgroundDepth4,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: CupertinoButton.filled(
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
      weightKg: double.tryParse(_weightController.text.trim()),
      duration: widget.plannedSet?.duration ?? widget.exercise.workDuration,
      unitRemaining: widget.plannedSet?.unitRemaining,
    );
  }

  String _plannedSetLabel(PlannedSet plannedSet) {
    final labelParts = <String>[];
    if (plannedSet.reps != null) labelParts.add('${plannedSet.reps} reps');
    if (plannedSet.weightKg != null) {
      labelParts.add('${_formatWeight(plannedSet.weightKg!)}kg');
    }
    if (plannedSet.duration != null) {
      labelParts.add('${plannedSet.duration!.inSeconds}s');
    }
    return labelParts.isEmpty ? 'set' : labelParts.join(' @ ');
  }

  String _formatWeight(double weightKg) {
    if (weightKg == weightKg.roundToDouble()) {
      return weightKg.round().toString();
    }
    return weightKg.toStringAsFixed(1);
  }
}
