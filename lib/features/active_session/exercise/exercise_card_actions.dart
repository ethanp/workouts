import 'package:flutter/cupertino.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';

class ExerciseCardActions extends StatelessWidget {
  const ExerciseCardActions({
    super.key,
    required this.completedSetCount,
    required this.plannedSetCount,
    required this.nextPlannedSet,
    required this.onLogSet,
    required this.onUnlogSet,
  });

  final int completedSetCount;
  final int plannedSetCount;
  final PlannedSet? nextPlannedSet;
  final VoidCallback onLogSet;
  final VoidCallback? onUnlogSet;

  @override
  Widget build(BuildContext context) {
    final isComplete =
        plannedSetCount > 0 && completedSetCount >= plannedSetCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactProgressLabel =
            isComplete || constraints.maxWidth < 360;
        return _actionRow(
          isComplete: isComplete,
          useCompactProgressLabel: useCompactProgressLabel,
        );
      },
    );
  }

  Widget _actionRow({
    required bool isComplete,
    required bool useCompactProgressLabel,
  }) {
    return Row(
      children: [
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          onPressed: onLogSet,
          child: Text(
            _logSetButtonLabel(isComplete),
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: AppColors.backgroundDepth3,
          disabledColor: AppColors.backgroundDepth4,
          borderRadius: BorderRadius.circular(AppRadius.md),
          onPressed: onUnlogSet,
          child: const Text(
            'Unlog',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        _progressBadge(
          isComplete: isComplete,
          useCompactLabel: useCompactProgressLabel,
        ),
      ],
    );
  }

  Widget _progressBadge({
    required bool isComplete,
    required bool useCompactLabel,
  }) {
    final background = isComplete
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.backgroundDepth3;
    final border = isComplete
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.borderDepth2;
    final textColor = isComplete ? AppColors.success : AppColors.textColor3;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Text(
        _progressLabel(useCompactLabel),
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  String _logSetButtonLabel(bool isComplete) {
    if (isComplete) return 'Log Extra Set';
    if (nextPlannedSet == null) return 'Log Set';
    return switch (nextPlannedSet!.type) {
      PlannedSetType.warmup => 'Log Warmup',
      PlannedSetType.working => 'Log Set',
    };
  }

  String _progressLabel(bool useCompactLabel) {
    if (useCompactLabel) return '$completedSetCount of $plannedSetCount';
    return '$completedSetCount of $plannedSetCount completed';
  }
}
