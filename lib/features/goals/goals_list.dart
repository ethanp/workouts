import 'package:flutter/cupertino.dart';
import 'package:workouts/features/goals/background_note_row.dart';
import 'package:workouts/features/goals/goal_category_style.dart';
import 'package:workouts/features/goals/goal_card.dart';
import 'package:workouts/features/goals/goals_list_chrome.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalsList extends StatelessWidget {
  const GoalsList({
    super.key,
    required this.activeGoals,
    required this.archivedGoals,
    required this.activeNotes,
    required this.archivedNotes,
    required this.allGoals,
    required this.showArchived,
    required this.onToggleArchived,
    required this.onAddGoal,
    required this.onAddNote,
  });

  final List<FitnessGoal> activeGoals;
  final List<FitnessGoal> archivedGoals;
  final List<BackgroundNote> activeNotes;
  final List<BackgroundNote> archivedNotes;
  final List<FitnessGoal> allGoals;
  final bool showArchived;
  final VoidCallback onToggleArchived;
  final VoidCallback onAddGoal;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      children: [
        ..._activeGoalsSection(),
        ..._activeNotesSection(),
        ..._emptySection(),
        ..._archivedSection(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

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
      ..._activeGoalCategorySections(),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _activeGoalCategorySections() {
    final goalCategoryWidgets = <Widget>[];
    for (final goalCategory in _activeGoalCategories()) {
      final categoryGoals = activeGoals
          .where((fitnessGoal) => fitnessGoal.category == goalCategory)
          .toList();
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

  List<GoalCategory> _activeGoalCategories() {
    final goalCategories = <GoalCategory>[];
    for (final fitnessGoal in activeGoals) {
      if (goalCategories.contains(fitnessGoal.category)) continue;
      goalCategories.add(fitnessGoal.category);
    }
    return goalCategories;
  }

  List<Widget> _activeNotesSection() {
    if (activeNotes.isEmpty) return [];
    return [
      GoalsSectionHeader(
        icon: CupertinoIcons.doc_text_fill,
        title: 'BACKGROUND',
        action: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onAddNote,
          child: const Text(
            'Add',
            style: TextStyle(fontSize: 14, color: AppColors.accentPrimary),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ...activeNotes.map(
        (note) => BackgroundNoteRow(note: note, allGoals: allGoals),
      ),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _emptySection() {
    if (activeGoals.isNotEmpty || activeNotes.isNotEmpty) return [];
    return [
      GoalsQuickAddRow(onAddGoal: onAddGoal, onAddNote: onAddNote),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _archivedSection() {
    final archivedCount = archivedGoals.length + archivedNotes.length;
    if (archivedCount == 0) return [];
    return [
      GoalsArchivedToggleRow(
        count: archivedCount,
        isExpanded: showArchived,
        onTap: onToggleArchived,
      ),
      if (showArchived) ...[
        const SizedBox(height: AppSpacing.sm),
        ...archivedGoals.map(
          (goal) => GoalCard(goal: goal, allGoals: allGoals, isArchived: true),
        ),
        ...archivedNotes.map(
          (note) => BackgroundNoteRow(
            note: note,
            allGoals: allGoals,
            isArchived: true,
          ),
        ),
      ],
    ];
  }
}

class _GoalCategoryHeader extends StatelessWidget {
  const _GoalCategoryHeader({required this.categoryStyle});

  final GoalCategoryStyle categoryStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}
