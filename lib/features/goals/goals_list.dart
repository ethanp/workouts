import 'package:flutter/cupertino.dart';
import 'package:workouts/features/goals/goal_category_style.dart';
import 'package:workouts/features/goals/goal_card.dart';
import 'package:workouts/features/goals/goals_list_chrome.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalsList extends StatelessWidget {
  const GoalsList({
    super.key,
    required this.activeGoals,
    required this.archivedGoals,
    required this.allGoals,
    required this.showArchived,
    required this.onToggleArchived,
    required this.onAddGoal,
  });

  final List<FitnessGoal> activeGoals;
  final List<FitnessGoal> archivedGoals;
  final List<FitnessGoal> allGoals;
  final bool showArchived;
  final VoidCallback onToggleArchived;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    children: [
      ..._activeGoalsSection(),
      ..._emptySection(),
      ..._archivedSection(),
      const SizedBox(height: AppSpacing.xxl),
    ],
  );

  List<Widget> _activeGoalsSection() {
    if (activeGoals.isEmpty) return [];
    return [
      GoalsSectionHeader(
        icon: CupertinoIcons.flag_fill,
        title: 'GOALS',
        action: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onAddGoal,
          child: const Text(
            'Add',
            style: TextStyle(fontSize: 14, color: AppColors.accentPrimary),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ..._activeGoalPrioritySections(),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _activeGoalPrioritySections() {
    final prioritySectionWidgets = <Widget>[];
    final goalPriorities = _activeGoalPriorities();
    for (final priority in goalPriorities) {
      prioritySectionWidgets.add(
        _GoalPriorityGroup(
          priority: priority,
          children: _activeGoalCategorySections(priority),
        ),
      );
      if (priority != goalPriorities.last) {
        prioritySectionWidgets.add(const SizedBox(height: AppSpacing.md));
      }
    }
    return prioritySectionWidgets;
  }

  List<int> _activeGoalPriorities() {
    final goalPriorities = activeGoals
        .map((fitnessGoal) => fitnessGoal.priority)
        .toSet()
        .toList();
    goalPriorities.sort();
    return goalPriorities;
  }

  List<Widget> _activeGoalCategorySections(int priority) {
    final goalCategoryWidgets = <Widget>[];
    for (final goalCategory in _activeGoalCategories(priority)) {
      final categoryGoals = _activeGoalsForCategory(priority, goalCategory);
      goalCategoryWidgets.add(
        _GoalCategoryHeader(categoryStyle: GoalCategoryStyle(goalCategory)),
      );
      goalCategoryWidgets.add(const SizedBox(height: AppSpacing.xs));
      goalCategoryWidgets.addAll(
        categoryGoals.map(
          (fitnessGoal) => GoalCard(
            goal: fitnessGoal,
            allGoals: allGoals,
            showCategoryPill: false,
          ),
        ),
      );
      goalCategoryWidgets.add(const SizedBox(height: AppSpacing.sm));
    }
    return goalCategoryWidgets;
  }

  List<GoalCategory> _activeGoalCategories(int priority) {
    final goalCategories = <GoalCategory>[];
    for (final fitnessGoal in activeGoals) {
      if (fitnessGoal.priority != priority) continue;
      if (goalCategories.contains(fitnessGoal.category)) continue;
      goalCategories.add(fitnessGoal.category);
    }
    goalCategories.sort(
      (firstCategory, secondCategory) => GoalCategoryStyle(
        firstCategory,
      ).label.compareTo(GoalCategoryStyle(secondCategory).label),
    );
    return goalCategories;
  }

  List<FitnessGoal> _activeGoalsForCategory(
    int priority,
    GoalCategory goalCategory,
  ) {
    final categoryGoals = activeGoals
        .where(
          (fitnessGoal) =>
              fitnessGoal.priority == priority &&
              fitnessGoal.category == goalCategory,
        )
        .toList();
    categoryGoals.sort(
      (firstGoal, secondGoal) => firstGoal.title.toLowerCase().compareTo(
        secondGoal.title.toLowerCase(),
      ),
    );
    return categoryGoals;
  }

  List<Widget> _emptySection() {
    if (activeGoals.isNotEmpty) return [];
    return [
      GoalsQuickAddRow(onAddGoal: onAddGoal),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _archivedSection() {
    if (archivedGoals.isEmpty) return [];
    return [
      GoalsArchivedToggleRow(
        count: archivedGoals.length,
        isExpanded: showArchived,
        onTap: onToggleArchived,
      ),
      if (showArchived) ...[
        const SizedBox(height: AppSpacing.sm),
        ...archivedGoals.map(
          (goal) => GoalCard(goal: goal, allGoals: allGoals, isArchived: true),
        ),
      ],
    ];
  }
}

class _GoalPriorityGroup extends StatelessWidget {
  const _GoalPriorityGroup({required this.priority, required this.children});

  final int priority;
  final List<Widget> children;

  Color get _priorityColor => switch (priority) {
    1 => CupertinoColors.systemYellow,
    2 => CupertinoColors.systemBlue,
    3 => CupertinoColors.systemGreen,
    _ => CupertinoColors.systemGrey,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _GoalPriorityHeader(priority: priority, color: _priorityColor),
      const SizedBox(height: AppSpacing.sm),
      ...children,
    ],
  );
}

class _GoalPriorityHeader extends StatelessWidget {
  const _GoalPriorityHeader({required this.priority, required this.color});

  final int priority;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        'PRIORITY $priority',
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Container(height: 1, color: color.withValues(alpha: 0.3)),
      ),
    ],
  );
}

class _GoalCategoryHeader extends StatelessWidget {
  const _GoalCategoryHeader({required this.categoryStyle});

  final GoalCategoryStyle categoryStyle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: categoryStyle.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          categoryStyle.label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: categoryStyle.color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            height: 1,
            color: categoryStyle.color.withValues(alpha: 0.20),
          ),
        ),
      ],
    ),
  );
}
