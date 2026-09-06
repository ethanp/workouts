import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/goals/goal_category_style.dart';
import 'package:workouts/features/goals/goal_card.dart';
import 'package:workouts/features/goals/goals_list_rows.dart';
import 'package:workouts/models/fitness_goal.dart';

class const GoalsList({
  required final List<FitnessGoal> activeGoals,
  required final List<FitnessGoal> archivedGoals,
  required final List<FitnessGoal> allGoals,
  required final bool showArchived,
  required final VoidCallback onToggleArchived,
  required final VoidCallback onAddGoal,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceLg,
      vertical: ELayout.spaceMd,
    ),
    children: [
      ..._activeGoalsSection(),
      ..._emptySection(),
      ..._archivedSection(),
      const SizedBox(height: 32),
    ],
  );

  List<Widget> _activeGoalsSection() {
    if (activeGoals.isEmpty) return [];
    return [
      GoalsSectionHeader(
        icon: Icons.flag,
        title: 'GOALS',
        action: TextButton(
          onPressed: onAddGoal,
          child: const Text(
            'Add',
            style: TextStyle(fontSize: 14, color: EColors.accent),
          ),
        ),
      ),
      const SizedBox(height: ELayout.spaceSm),
      ..._activeGoalPrioritySections(),
      const SizedBox(height: ELayout.spaceXl),
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
        prioritySectionWidgets.add(const SizedBox(height: ELayout.spaceMd));
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
      goalCategoryWidgets.add(const SizedBox(height: ELayout.spaceXs));
      goalCategoryWidgets.addAll(
        categoryGoals.map(
          (fitnessGoal) => GoalCard(
            goal: fitnessGoal,
            allGoals: allGoals,
            showCategoryPill: false,
          ),
        ),
      );
      goalCategoryWidgets.add(const SizedBox(height: ELayout.spaceSm));
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
      (firstCategory, secondCategory) =>
          GoalCategoryStyle(firstCategory).label
              .compareTo(GoalCategoryStyle(secondCategory).label),
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
      const SizedBox(height: ELayout.spaceXl),
    ];
  }

  List<Widget> _archivedSection() {
    if (archivedGoals.isEmpty) return [];
    return [
      GoalsArchivedToggleRow(
        count: archivedGoals.length,
        isExpanded: showArchived,
        onArchivedSectionToggled: onToggleArchived,
      ),
      if (showArchived) ...[
        const SizedBox(height: ELayout.spaceSm),
        ...archivedGoals.map(
          (goal) => GoalCard(goal: goal, allGoals: allGoals, isArchived: true),
        ),
      ],
    ];
  }
}

class const _GoalPriorityGroup({
  required final int priority,
  required final List<Widget> children,
}) extends StatelessWidget {
  Color get _priorityColor => switch (priority) {
    1 => EColors.warning,
    2 => EColors.accent,
    3 => EColors.success,
    _ => EColors.textMuted,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _GoalPriorityHeader(priority: priority, color: _priorityColor),
      const SizedBox(height: ELayout.spaceSm),
      ...children,
    ],
  );
}

class const _GoalPriorityHeader({
  required final int priority,
  required final Color color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        'PRIORITY $priority',
        style: EText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
      const SizedBox(width: ELayout.spaceSm),
      Expanded(
        child: Container(height: 1, color: color.withValues(alpha: 0.3)),
      ),
    ],
  );
}

class const _GoalCategoryHeader({
  required final GoalCategoryStyle categoryStyle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: ELayout.spaceXs),
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
        const SizedBox(width: ELayout.spaceSm),
        Text(
          categoryStyle.label.toUpperCase(),
          style: EText.caption.copyWith(
            color: categoryStyle.color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: ELayout.spaceSm),
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
