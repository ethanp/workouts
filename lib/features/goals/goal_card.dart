import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goal_category_style.dart';
import 'package:workouts/features/goals/goal_form_sheet.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class GoalCard extends ConsumerWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.allGoals,
    this.isArchived = false,
    this.showCategoryPill = true,
  });

  final FitnessGoal goal;
  final List<FitnessGoal> allGoals;
  final bool isArchived;
  final bool showCategoryPill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryStyle = GoalCategoryStyle(goal.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundDepth2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isArchived
                    ? AppColors.borderDepth1.withValues(alpha: 0.5)
                    : AppColors.borderDepth1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _cardContent(categoryStyle)),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.textColor4,
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
      color: AppColors.error,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: AppSpacing.lg),
    child: const Icon(
      CupertinoIcons.trash,
      color: CupertinoColors.white,
      size: 22,
    ),
  );

  Widget _cardContent(GoalCategoryStyle categoryStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goal.title,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isArchived ? AppColors.textColor3 : AppColors.textColor2,
          ),
        ),
        if (_showsStatusRow) ...[
          const SizedBox(height: AppSpacing.xs),
          _statusRow(categoryStyle),
        ],
        if (goal.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _descriptionText(),
        ],
      ],
    );
  }

  bool get _showsStatusRow {
    return showCategoryPill || goal.status != GoalStatus.active;
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
        if (goal.status == GoalStatus.achieved) ..._achievedBadge(),
        if (goal.status == GoalStatus.paused) ..._pausedBadge(),
      ],
    );
  }

  List<Widget> _achievedBadge() => [
    const SizedBox(width: AppSpacing.sm),
    const Icon(
      CupertinoIcons.checkmark_seal_fill,
      size: 13,
      color: AppColors.success,
    ),
    const SizedBox(width: 3),
    Text(
      'Achieved',
      style: AppTypography.caption.copyWith(
        fontSize: 12,
        color: AppColors.success,
      ),
    ),
  ];

  List<Widget> _pausedBadge() => [
    const SizedBox(width: AppSpacing.sm),
    const Icon(
      CupertinoIcons.pause_circle_fill,
      size: 13,
      color: AppColors.textColor4,
    ),
    const SizedBox(width: 3),
    Text(
      'Archived',
      style: AppTypography.caption.copyWith(
        fontSize: 12,
        color: AppColors.textColor4,
      ),
    ),
  ];

  Widget _descriptionText() => Text(
    goal.description,
    style: AppTypography.caption.copyWith(color: AppColors.textColor4),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );

  void _showActions(BuildContext context, WidgetRef ref) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: Text(goal.title),
        actions: _actionSheetActions(sheetCtx, context, ref, goalsNotifier),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetCtx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  List<CupertinoActionSheetAction> _actionSheetActions(
    BuildContext sheetCtx,
    BuildContext parentCtx,
    WidgetRef ref,
    GoalsController goalsNotifier,
  ) {
    final isActive = goal.status == GoalStatus.active;
    return [
      CupertinoActionSheetAction(
        onPressed: () {
          Navigator.of(sheetCtx).pop();
          _showEditSheet(parentCtx, ref);
        },
        child: const Text('Edit'),
      ),
      if (isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            goalsNotifier.setGoalStatus(goal.id, GoalStatus.achieved);
          },
          child: const Text('Mark as Achieved'),
        ),
      if (isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            goalsNotifier.setGoalStatus(goal.id, GoalStatus.paused);
          },
          child: const Text('Archive'),
        ),
      if (!isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            goalsNotifier.setGoalStatus(goal.id, GoalStatus.active);
          },
          child: const Text('Reactivate'),
        ),
      CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.of(sheetCtx).pop();
          goalsNotifier.deleteGoal(goal.id);
        },
        child: const Text('Delete'),
      ),
    ];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showCupertinoModalPopup<void>(
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.color,
    this.isArchived = false,
  });

  final String label;
  final Color color;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isArchived ? color.withValues(alpha: 0.4) : color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
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
