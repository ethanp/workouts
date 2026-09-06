import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const GoalsSectionHeader({
  required final IconData icon,
  required final String title,
  final Widget? action,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: EColors.textMuted),
        const SizedBox(width: ELayout.spaceXs),
        Text(
          title,
          style: EText.caption.copyWith(
            color: EColors.textMuted,
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
        padding: const EdgeInsets.symmetric(vertical: ELayout.spaceXs),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.expand_more
                  : Icons.chevron_right,
              size: 12,
              color: EColors.textMuted,
            ),
            const SizedBox(width: ELayout.spaceSm),
            Text(
              isExpanded ? 'Hide Archived' : 'Show Archived ($count)',
              style: EText.caption.copyWith(
                color: EColors.textMuted,
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
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onAddGoal,
          child: const Text(
            'Add Your First Goal',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
