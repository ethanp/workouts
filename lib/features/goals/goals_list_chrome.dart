import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class const GoalsSectionHeader({
  required final IconData icon,
  required final String title,
  final Widget? action,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textColor4),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class const GoalsArchivedToggleRow({
  required final int count,
  required final bool isExpanded,
  required final VoidCallback onArchivedSectionToggled,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onArchivedSectionToggled,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_right,
              size: 12,
              color: AppColors.textColor4,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isExpanded ? 'Hide Archived' : 'Show Archived ($count)',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const GoalsQuickAddRow({required final VoidCallback onAddGoal})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        CupertinoButton.filled(
          onPressed: onAddGoal,
          child: const Text(
            'Add Your First Goal',
            style: TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
