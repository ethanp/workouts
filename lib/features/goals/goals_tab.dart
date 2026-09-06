import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goal_form_sheet.dart';
import 'package:workouts/features/goals/goals_empty_state.dart';
import 'package:workouts/features/goals/goals_list.dart';
import 'package:workouts/features/goals/goals_provider.dart';

class const GoalsTab() extends ConsumerStatefulWidget {
  @override
  ConsumerState<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState() extends ConsumerState<GoalsTab> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        final activeGoals = goals.where((goal) => goal.isActive).toList()
          ..sort(
            (firstGoal, secondGoal) =>
                firstGoal.priority.compareTo(secondGoal.priority),
          );
        final archivedGoals = goals.where((goal) => !goal.isActive).toList();

        if (goals.isEmpty) {
          return GoalsEmptyState(onAddGoal: () => _showAddGoalSheet(context));
        }

        return GoalsList(
          activeGoals: activeGoals,
          archivedGoals: archivedGoals,
          allGoals: goals,
          showArchived: _showArchived,
          onToggleArchived: () =>
              setState(() => _showArchived = !_showArchived),
          onAddGoal: () => _showAddGoalSheet(context),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: EText.body.medium.copyWith(color: EColors.danger),
        ),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => GoalFormSheet(
        onSave: (title, category, description, priority) async {
          await goalsNotifier.addGoal(
            title: title,
            category: category,
            description: description,
            priority: priority,
          );
        },
      ),
    );
  }
}
