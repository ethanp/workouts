import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalsSectionHeader extends StatelessWidget {
  const GoalsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? action;

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

class GoalsArchivedToggleRow extends StatelessWidget {
  const GoalsArchivedToggleRow({
    super.key,
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

class GoalsQuickAddRow extends StatelessWidget {
  const GoalsQuickAddRow({
    super.key,
    required this.onAddGoal,
    required this.onAddNote,
  });

  final VoidCallback onAddGoal;
  final VoidCallback onAddNote;

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
        CupertinoButton(
          onPressed: onAddNote,
          child: Text(
            'Or add a background note',
            style: TextStyle(color: AppColors.accentPrimary),
          ),
        ),
      ],
    );
  }
}
