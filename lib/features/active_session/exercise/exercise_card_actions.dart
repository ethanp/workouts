import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/workout_exercise.dart';

class const ExerciseCardActions({
  required final int completedSetCount,
  required final int plannedSetCount,
  required final PlannedSet? nextPlannedSet,
  required final VoidCallback onLogSet,
  required final VoidCallback? onUnlogSet,
  final VoidCallback? onAddWarmupSet,
  final VoidCallback? onRemoveWarmupSet,

  /// Number of sides logged per planned set (2 for unilateral). When > 1 the
  /// log button labels itself "Log Side N" so the user knows which side they
  /// are recording.
  final int sidesPerSet = 1,
  final int currentSide = 1,
}) extends StatelessWidget {
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
        final isCrowded =
            _showsWarmupGroup || onUnlogSet != null || sidesPerSet > 1;
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
          const SizedBox(width: ELayout.spaceSm),
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
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMinus)
            _warmupIconButton(
              icon: Icons.remove_circle_outline,
              onPressed: onRemoveWarmupSet!,
            ),
          Padding(
            // When an icon button is adjacent, its own internal padding
            // already separates it from the label so xs is enough; when
            // there's no icon on a given side, fall back to md so the label
            // doesn't kiss the pill edge.
            padding: EdgeInsets.only(
              left: hasMinus ? ELayout.spaceXs : ELayout.spaceMd,
              right: hasPlus ? ELayout.spaceXs : ELayout.spaceMd,
            ),
            child: Text(
              'Warmup',
              style: EText.caption.copyWith(
                color: EColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (hasPlus)
            _warmupIconButton(
              icon: Icons.add_circle_outline,
              onPressed: onAddWarmupSet!,
            ),
        ],
      ),
    );
  }

  Widget _warmupIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(32, 32),
      padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceSm),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18, color: EColors.textSecondary),
  );

  /// Combined log / unlog pill, mirroring the warmup group: one rounded
  /// control with the primary "Log" tap region on the left and a secondary
  /// undo icon on the right when there's a logged set to remove. One pill
  /// avoids the overflow from pairing a filled "Log" button with a separate
  /// "Unlog" control.
  Widget _logGroup({required bool isComplete}) {
    return Container(
      decoration: BoxDecoration(
        color: EColors.accent,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: ELayout.spaceLg,
                vertical: ELayout.spaceSm,
              ),
            ),
            onPressed: onLogSet,
            child: Text(
              _logSetButtonLabel(isComplete),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onUnlogSet != null) ...[
            Container(
              width: 1,
              height: 20,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              onPressed: onUnlogSet,
              icon: const Icon(Icons.undo, size: 18, color: Colors.white),
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
        ? EColors.success.withValues(alpha: 0.15)
        : EColors.surface;
    final border = isComplete
        ? EColors.success.withValues(alpha: 0.3)
        : EColors.borderStrong;
    final textColor = isComplete ? EColors.success : EColors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceMd,
        vertical: ELayout.spaceSm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        border: Border.all(color: border),
      ),
      child: Text(
        _progressLabel(useCompactLabel),
        style: EText.caption.copyWith(
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
