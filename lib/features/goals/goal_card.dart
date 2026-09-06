import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goal_category_style.dart';
import 'package:workouts/features/goals/goal_form_sheet.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class const GoalCard({
  required final FitnessGoal goal,
  required final List<FitnessGoal> allGoals,
  final bool isArchived = false,
  final bool showCategoryPill = true,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryStyle = GoalCategoryStyle(goal.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: GestureDetector(
        onTap: () => _showActions(context, ref),
        child: Dismissible(
          key: ValueKey(goal.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context),
          onDismissed: (_) =>
              ref.read(goalsControllerProvider.notifier).deleteGoal(goal.id),
          background: _deleteBackground(),
          child: Container(
            padding: const EdgeInsets.all(ELayout.spaceMd),
            decoration: BoxDecoration(
              color: EColors.backgroundLift,
              borderRadius: BorderRadius.circular(ELayout.radiusMd),
              border: Border.all(
                color: isArchived
                    ? EColors.border.withValues(alpha: 0.5)
                    : EColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _cardContent(categoryStyle)),
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: EColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) => confirmDeleteDialog(
    context,
    title: 'Delete Goal?',
    content: '"${goal.title}" will be permanently deleted.',
  );

  Widget _deleteBackground() => Container(
    decoration: BoxDecoration(
      color: EColors.danger,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: ELayout.spaceLg),
    child: const Icon(
      Icons.delete,
      color: Colors.white,
      size: 22,
    ),
  );

  Widget _cardContent(GoalCategoryStyle categoryStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goal.title,
          style: EText.body.medium.copyWith(
            fontWeight: FontWeight.w600,
            color: isArchived ? EColors.textTertiary : EColors.textSecondary,
          ),
        ),
        if (_showsStatusRow) ...[
          const SizedBox(height: ELayout.spaceXs),
          _statusRow(categoryStyle),
        ],
        if (goal.description.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceXs),
          _descriptionText(),
        ],
      ],
    );
  }

  bool get _showsStatusRow {
    return showCategoryPill || !goal.isActive;
  }

  Widget _statusRow(GoalCategoryStyle categoryStyle) {
    return Row(
      children: [
        if (showCategoryPill)
          _CategoryPill(
            label: categoryStyle.label,
            color: categoryStyle.color,
            isArchived: isArchived,
          ),
        if (goal.isAchieved) ..._achievedBadge(),
        if (goal.isPaused) ..._pausedBadge(),
      ],
    );
  }

  List<Widget> _achievedBadge() => [
    const SizedBox(width: ELayout.spaceSm),
    const Icon(
      Icons.verified,
      size: 13,
      color: EColors.success,
    ),
    const SizedBox(width: 3),
    Text(
      'Achieved',
      style: EText.caption.copyWith(
        fontSize: 12,
        color: EColors.success,
      ),
    ),
  ];

  List<Widget> _pausedBadge() => [
    const SizedBox(width: ELayout.spaceSm),
    const Icon(
      Icons.pause_circle_outline,
      size: 13,
      color: EColors.textMuted,
    ),
    const SizedBox(width: 3),
    Text(
      'Archived',
      style: EText.caption.copyWith(
        fontSize: 12,
        color: EColors.textMuted,
      ),
    ),
  ];

  Widget _descriptionText() => Text(
    goal.description,
    style: EText.caption.copyWith(color: EColors.textMuted),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );

  void _showActions(BuildContext context, WidgetRef ref) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(goal.title)),
            ..._actionSheetActions(sheetCtx, context, ref, goalsNotifier),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetCtx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionSheetActions(
    BuildContext sheetCtx,
    BuildContext parentCtx,
    WidgetRef ref,
    GoalsController goalsNotifier,
  ) {
    final isActive = goal.isActive;
    return [
      ListTile(
        title: const Text('Edit'),
        onTap: () {
          Navigator.of(sheetCtx).pop();
          _showEditSheet(parentCtx, ref);
        },
      ),
      if (isActive)
        ListTile(
          title: const Text('Mark as Achieved'),
          onTap: () {
            Navigator.of(sheetCtx).pop();
            goalsNotifier.setGoalStatus(goal.id, GoalStatus.achieved);
          },
        ),
      if (isActive)
        ListTile(
          title: const Text('Archive'),
          onTap: () {
            Navigator.of(sheetCtx).pop();
            goalsNotifier.setGoalStatus(goal.id, GoalStatus.paused);
          },
        ),
      if (!isActive)
        ListTile(
          title: const Text('Reactivate'),
          onTap: () {
            Navigator.of(sheetCtx).pop();
            goalsNotifier.setGoalStatus(goal.id, GoalStatus.active);
          },
        ),
      ListTile(
        title: Text('Delete', style: TextStyle(color: EColors.danger)),
        onTap: () {
          Navigator.of(sheetCtx).pop();
          goalsNotifier.deleteGoal(goal.id);
        },
      ),
    ];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => GoalFormSheet(
        initialGoal: goal,
        onSave: (title, category, description, priority) async {
          await goalsNotifier.updateGoal(
            goal.copyWith(
              title: title,
              category: category,
              description: description,
              priority: priority,
              updatedAt: DateTime.now(),
            ),
          );
        },
      ),
    );
  }
}

class const _CategoryPill({
  required final String label,
  required final Color color,
  final bool isArchived = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final effectiveColor = isArchived ? color.withValues(alpha: 0.4) : color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: effectiveColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
