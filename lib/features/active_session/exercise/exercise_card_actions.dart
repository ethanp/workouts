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
    this.onAddWarmupSet,
    this.onRemoveWarmupSet,
    this.sidesPerSet = 1,
    this.currentSide = 1,
  });

  final int completedSetCount;
  final int plannedSetCount;
  final PlannedSet? nextPlannedSet;
  final VoidCallback onLogSet;
  final VoidCallback? onUnlogSet;
  final VoidCallback? onAddWarmupSet;
  final VoidCallback? onRemoveWarmupSet;

  /// Number of sides logged per planned set (2 for unilateral). When > 1 the
  /// log button labels itself "Log Side N" so the user knows which side they
  /// are recording.
  final int sidesPerSet;
  final int currentSide;

  @override
  Widget build(BuildContext context) {
    final isComplete =
        plannedSetCount > 0 && completedSetCount >= plannedSetCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones (logical width 375..430) cannot fit the log pill + warmup
        // pill + "X of N completed" badge on one line, so drop the trailing
        // "completed" word whenever the warmup group is visible, an unlog
        // button is present, the exercise is unilateral, or the row is just
        // narrow. Tablets (>=500 logical) still get the full label.
        final isCrowded = _showsWarmupGroup ||
            onUnlogSet != null ||
            sidesPerSet > 1;
        final useCompactProgressLabel =
            isComplete || isCrowded || constraints.maxWidth < 500;
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
        _logGroup(isComplete: isComplete),
        const Spacer(),
        if (_showsWarmupGroup) ...[
          _warmupGroup(),
          const SizedBox(width: AppSpacing.sm),
        ],
        _progressBadge(
          isComplete: isComplete,
          useCompactLabel: useCompactProgressLabel,
        ),
      ],
    );
  }

  bool get _showsWarmupGroup =>
      onAddWarmupSet != null || onRemoveWarmupSet != null;

  /// Single pill containing the "Warmup" label flanked by minus / plus icon
  /// buttons. Replaces the prior pair of independent chips that each repeated
  /// the word "Warmup" — saves enough horizontal space that the action row
  /// no longer overflows once both add and remove are available.
  Widget _warmupGroup() {
    final hasMinus = onRemoveWarmupSet != null;
    final hasPlus = onAddWarmupSet != null;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMinus)
            _warmupIconButton(
              icon: CupertinoIcons.minus_circle,
              onPressed: onRemoveWarmupSet!,
            ),
          Padding(
            // When an icon button is adjacent, its own internal padding
            // already separates it from the label so xs is enough; when
            // there's no icon on a given side, fall back to md so the label
            // doesn't kiss the pill edge.
            padding: EdgeInsets.only(
              left: hasMinus ? AppSpacing.xs : AppSpacing.md,
              right: hasPlus ? AppSpacing.xs : AppSpacing.md,
            ),
            child: Text(
              'Warmup',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (hasPlus)
            _warmupIconButton(
              icon: CupertinoIcons.plus_circle,
              onPressed: onAddWarmupSet!,
            ),
        ],
      ),
    );
  }

  Widget _warmupIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    minimumSize: const Size(32, 32),
    onPressed: onPressed,
    child: Icon(icon, size: 18, color: AppColors.textColor2),
  );

  /// Combined log / unlog pill, mirroring the structure of the warmup group:
  /// a single rounded chrome with the primary "Log" tap region on the left
  /// and a secondary undo icon on the right when there's a logged set to
  /// remove. Single piece of chrome avoids the previous overflow caused by
  /// pairing an independent filled "Log" button with a separate "Unlog" pill.
  Widget _logGroup({required bool isComplete}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
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
          if (onUnlogSet != null) ...[
            Container(
              width: 1,
              height: 20,
              color: CupertinoColors.white.withValues(alpha: 0.3),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              onPressed: onUnlogSet,
              child: const Icon(
                CupertinoIcons.arrow_uturn_left,
                size: 18,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ],
      ),
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
    final isUnilateral = sidesPerSet > 1;
    if (nextPlannedSet == null) {
      return isUnilateral ? 'Log Side $currentSide' : 'Log Set';
    }
    return switch (nextPlannedSet!.type) {
      // Warmup keeps the bare "Log Warmup" label even when unilateral; the
      // current-set editor caption right above already says "Side N of 2",
      // and adding the suffix here pushes the action row into overflow when
      // the unlog button + warmup chips + progress badge are all visible.
      PlannedSetType.warmup => 'Log Warmup',
      PlannedSetType.working =>
        isUnilateral ? 'Log Side $currentSide' : 'Log Set',
    };
  }

  String _progressLabel(bool useCompactLabel) {
    if (useCompactLabel) return '$completedSetCount of $plannedSetCount';
    return '$completedSetCount of $plannedSetCount completed';
  }
}
