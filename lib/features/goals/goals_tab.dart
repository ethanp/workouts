import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goal_form_sheet.dart';
import 'package:workouts/features/goals/goals_empty_state.dart';
import 'package:workouts/features/goals/goals_list.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalsTab extends ConsumerStatefulWidget {
  const GoalsTab({super.key});

  @override
  ConsumerState<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends ConsumerState<GoalsTab> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        final activeGoals =
            goals.where((goal) => goal.status == GoalStatus.active).toList()
              ..sort(
                (firstGoal, secondGoal) =>
                    firstGoal.priority.compareTo(secondGoal.priority),
              );
        final archivedGoals = goals
            .where((goal) => goal.status != GoalStatus.active)
            .toList();

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
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showCupertinoModalPopup<void>(
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
