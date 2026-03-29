import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/providers/background_notes_provider.dart';
import 'package:workouts/providers/goals_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class GoalsTab extends ConsumerStatefulWidget {
  const GoalsTab({super.key, required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  ConsumerState<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends ConsumerState<GoalsTab> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);
    final notesAsync = ref.watch(backgroundNotesStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        final notes = notesAsync.value ?? [];
        final activeGoals = goals
            .where((goal) => goal.status == GoalStatus.active)
            .toList()
          ..sort((firstGoal, secondGoal) =>
              firstGoal.priority.compareTo(secondGoal.priority));
        final archivedGoals = goals
            .where((goal) => goal.status != GoalStatus.active)
            .toList();
        final activeNotes = notes.where((note) => note.isActive).toList();
        final archivedNotes = notes.where((note) => !note.isActive).toList();

        if (goals.isEmpty && notes.isEmpty) {
          return _EmptyState(onAddGoal: () => _showAddGoalSheet(context));
        }

        return _GoalsList(
          activeGoals: activeGoals,
          archivedGoals: archivedGoals,
          activeNotes: activeNotes,
          archivedNotes: archivedNotes,
          allGoals: goals,
          showArchived: _showArchived,
          onToggleArchived: () =>
              setState(() => _showArchived = !_showArchived),
          onAddGoal: () => _showAddGoalSheet(context),
          onAddNote: () => _showAddNoteSheet(context, goals),
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => GoalFormSheet(
        onSave: (title, category, description, priority) async {
          await ref.read(goalsControllerProvider.notifier).addGoal(
                title: title,
                category: category,
                description: description,
                priority: priority,
              );
        },
      ),
    );
  }

  void _showAddNoteSheet(BuildContext context, List<FitnessGoal> goals) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => NoteFormSheet(
        availableGoals: goals,
        onSave: (content, category, goalId) {
          ref
              .read(backgroundNotesControllerProvider.notifier)
              .addNote(content: content, category: category, goalId: goalId);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _GoalsList extends ConsumerWidget {
  const _GoalsList({
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
  Widget build(BuildContext context, WidgetRef ref) {
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
      _SectionLabel(
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
      ...activeGoals.map((goal) => _GoalCard(goal: goal, allGoals: allGoals)),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _activeNotesSection() {
    if (activeNotes.isEmpty) return [];
    return [
      _SectionLabel(
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
      ...activeNotes.map((note) => _NoteRow(note: note, allGoals: allGoals)),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _emptySection() {
    if (activeGoals.isNotEmpty || activeNotes.isNotEmpty) return [];
    return [
      _QuickAddRow(onAddGoal: onAddGoal, onAddNote: onAddNote),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _archivedSection() {
    final archivedCount = archivedGoals.length + archivedNotes.length;
    if (archivedCount == 0) return [];
    return [
      _ArchivedToggleRow(
        count: archivedCount,
        isExpanded: showArchived,
        onTap: onToggleArchived,
      ),
      if (showArchived) ...[
        const SizedBox(height: AppSpacing.sm),
        ...archivedGoals.map(
          (goal) => _GoalCard(goal: goal, allGoals: allGoals, isArchived: true),
        ),
        ...archivedNotes.map(
          (note) => _NoteRow(note: note, allGoals: allGoals, isArchived: true),
        ),
      ],
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
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

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.allGoals,
    this.isArchived = false,
  });

  final FitnessGoal goal;
  final List<FitnessGoal> allGoals;
  final bool isArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _categoryColor(goal.category);

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
                _PriorityBadge(
                  priority: goal.priority,
                  color: categoryColor,
                  isArchived: isArchived,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _cardContent(categoryColor)),
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

  Future<bool> _confirmDelete(BuildContext context) =>
      confirmDeleteDialog(
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
    child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white, size: 22),
  );

  Widget _cardContent(Color categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goal.title,
          style: AppTypography.subtitle.copyWith(
            color: isArchived ? AppColors.textColor3 : AppColors.textColor1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _statusRow(categoryColor),
        if (goal.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _descriptionText(),
        ],
      ],
    );
  }

  Widget _statusRow(Color categoryColor) {
    return Row(
      children: [
        _CategoryPill(
          label: _categoryLabel(goal.category),
          color: categoryColor,
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: Text(goal.title),
        actions: _actionSheetActions(sheetCtx, context, ref),
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
            ref
                .read(goalsControllerProvider.notifier)
                .setGoalStatus(goal.id, GoalStatus.achieved);
          },
          child: const Text('Mark as Achieved'),
        ),
      if (isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            ref
                .read(goalsControllerProvider.notifier)
                .setGoalStatus(goal.id, GoalStatus.paused);
          },
          child: const Text('Archive'),
        ),
      if (!isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            ref
                .read(goalsControllerProvider.notifier)
                .setGoalStatus(goal.id, GoalStatus.active);
          },
          child: const Text('Reactivate'),
        ),
      CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.of(sheetCtx).pop();
          ref.read(goalsControllerProvider.notifier).deleteGoal(goal.id);
        },
        child: const Text('Delete'),
      ),
    ];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => GoalFormSheet(
        initialGoal: goal,
        onSave: (title, category, description, priority) async {
          await ref.read(goalsControllerProvider.notifier).updateGoal(
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

  String _categoryLabel(GoalCategory category) {
    return category.name
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .toLowerCase();
  }

  Color _categoryColor(GoalCategory category) {
    return switch (category) {
      GoalCategory.strength || GoalCategory.power => AppColors.error,
      GoalCategory.endurance || GoalCategory.quickness => AppColors.warning,
      GoalCategory.mobility ||
      GoalCategory.balance ||
      GoalCategory.coordination =>
        AppColors.accentSecondary,
      GoalCategory.physique || GoalCategory.posture => AppColors.accentPrimary,
      GoalCategory.rehabilitation ||
      GoalCategory.longevity =>
        AppColors.success,
      GoalCategory.skill => AppColors.textColor2,
    };
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({
    required this.priority,
    required this.color,
    this.isArchived = false,
  });

  final int priority;
  final Color color;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isArchived ? color.withValues(alpha: 0.4) : color;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        '$priority',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: effectiveColor,
        ),
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
    final effectiveColor =
        isArchived ? color.withValues(alpha: 0.4) : color;
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

class _NoteRow extends ConsumerWidget {
  const _NoteRow({
    required this.note,
    required this.allGoals,
    this.isArchived = false,
  });

  final BackgroundNote note;
  final List<FitnessGoal> allGoals;
  final bool isArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedGoal = note.goalId != null
        ? allGoals
            .where((goal) => goal.id == note.goalId)
            .firstOrNull
        : null;
    final categoryColor = _categoryColor(note.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _showActions(context, ref),
        child: Dismissible(
          key: ValueKey(note.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context),
          onDismissed: (_) => ref
              .read(backgroundNotesControllerProvider.notifier)
              .deleteNote(note.id),
          background: _deleteBackground(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.backgroundDepth2,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isArchived
                    ? AppColors.borderDepth1.withValues(alpha: 0.4)
                    : AppColors.borderDepth1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  note.category.icon,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _noteContent(linkedGoal, categoryColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) =>
      confirmDeleteDialog(
        context,
        title: 'Delete Note?',
        content: 'This background note will be permanently deleted.',
      );

  Widget _deleteBackground() => Container(
    decoration: BoxDecoration(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: AppSpacing.lg),
    child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white, size: 22),
  );

  Widget _noteContent(FitnessGoal? linkedGoal, Color categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contentText(),
        const SizedBox(height: 3),
        _noteMeta(linkedGoal, categoryColor),
      ],
    );
  }

  Widget _contentText() => Text(
        note.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body.copyWith(
          color: isArchived ? AppColors.textColor3 : AppColors.textColor2,
          fontSize: 14,
        ),
      );

  Widget _noteMeta(FitnessGoal? linkedGoal, Color categoryColor) {
    return Row(
      children: [
        _categoryTag(categoryColor),
        if (linkedGoal != null) ..._linkedGoalIndicator(linkedGoal),
      ],
    );
  }

  Widget _categoryTag(Color categoryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        note.category.displayName,
        style: TextStyle(
          fontSize: 10,
          color: categoryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Widget> _linkedGoalIndicator(FitnessGoal linkedGoal) => [
        const SizedBox(width: AppSpacing.sm),
        const Icon(CupertinoIcons.link, size: 11, color: AppColors.textColor4),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            linkedGoal.title,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: AppColors.textColor4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];

  void _showActions(BuildContext context, WidgetRef ref) {
    final preview = note.content.length > 50
        ? '${note.content.substring(0, 50)}…'
        : note.content;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: Text(preview),
        actions: _noteActionSheetActions(sheetCtx, context, ref),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetCtx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  List<CupertinoActionSheetAction> _noteActionSheetActions(
    BuildContext sheetCtx,
    BuildContext parentCtx,
    WidgetRef ref,
  ) {
    return [
      CupertinoActionSheetAction(
        onPressed: () {
          Navigator.of(sheetCtx).pop();
          _showEditSheet(parentCtx, ref);
        },
        child: const Text('Edit'),
      ),
      if (note.isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            ref
                .read(backgroundNotesControllerProvider.notifier)
                .archiveNote(note.id);
          },
          child: const Text('Archive'),
        ),
      if (!note.isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            ref
                .read(backgroundNotesControllerProvider.notifier)
                .activateNote(note.id);
          },
          child: const Text('Reactivate'),
        ),
      CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.of(sheetCtx).pop();
          ref
              .read(backgroundNotesControllerProvider.notifier)
              .deleteNote(note.id);
        },
        child: const Text('Delete'),
      ),
    ];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => NoteFormSheet(
        availableGoals: allGoals,
        initialNote: note,
        onSave: (content, category, goalId) {
          ref.read(backgroundNotesControllerProvider.notifier).updateNote(
                note.copyWith(
                  content: content,
                  category: category,
                  goalId: goalId,
                ),
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Color _categoryColor(NoteCategory category) {
    return switch (category) {
      NoteCategory.injuryHistory => AppColors.error,
      NoteCategory.avoid => AppColors.warning,
      NoteCategory.medical => AppColors.error,
      NoteCategory.preference => AppColors.accentSecondary,
      NoteCategory.equipment => AppColors.accentPrimary,
      NoteCategory.constraint => AppColors.warning,
      NoteCategory.philosophy => AppColors.success,
    };
  }
}

class _ArchivedToggleRow extends StatelessWidget {
  const _ArchivedToggleRow({
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
              style: AppTypography.caption.copyWith(color: AppColors.textColor4),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({required this.onAddGoal, required this.onAddNote});

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddGoal});

  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                CupertinoIcons.flag_fill,
                size: 32,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('No Goals Yet', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add goals to personalise your training and track what matters.',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
              textAlign: TextAlign.center,
            ),
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
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared form sheets (moved from goals_screen.dart)
// ---------------------------------------------------------------------------

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({
    super.key,
    this.initialGoal,
    required this.onSave,
  });

  final FitnessGoal? initialGoal;
  final Future<void> Function(
    String title,
    GoalCategory category,
    String description,
    int priority,
  ) onSave;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late GoalCategory _selectedCategory;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialGoal?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialGoal?.description ?? '');
    _selectedCategory =
        widget.initialGoal?.category ?? GoalCategory.strength;
    _priority = widget.initialGoal?.priority ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialGoal != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragHandle(),
              const SizedBox(height: AppSpacing.lg),
              _sheetTitle(isEditing),
              const SizedBox(height: AppSpacing.xl),
              _titleField(),
              const SizedBox(height: AppSpacing.lg),
              _categoryField(),
              const SizedBox(height: AppSpacing.lg),
              _priorityField(),
              const SizedBox(height: AppSpacing.lg),
              _descriptionField(),
              const SizedBox(height: AppSpacing.xl),
              _saveButton(context, isEditing),
              const SizedBox(height: AppSpacing.md),
              _cancelButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderDepth3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sheetTitle(bool isEditing) => Text(
        isEditing ? 'Edit Goal' : 'New Goal',
        style: AppTypography.title,
        textAlign: TextAlign.center,
      );

  Widget _titleField() => _FormField(
        label: 'Title',
        child: CupertinoTextField(
          controller: _titleController,
          placeholder: 'e.g., Improve posture',
          onChanged: (_) => setState(() {}),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor4,
          ),
        ),
      );

  Widget _categoryField() => _FormField(
        label: 'Category',
        child: SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: GoalCategory.values.map((cat) {
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : AppColors.backgroundDepth3,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentPrimary
                            : AppColors.borderDepth2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? CupertinoColors.white
                            : AppColors.textColor2,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );

  Widget _priorityField() => _FormField(
        label: 'Priority  (1 = highest)',
        child: Row(
          children: List.generate(5, (index) {
            final priority = index + 1;
            final isSelected = priority == _priority;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: GestureDetector(
                onTap: () => setState(() => _priority = priority),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.backgroundDepth3,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : AppColors.borderDepth2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$priority',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? CupertinoColors.white
                          : AppColors.textColor2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  Widget _descriptionField() => _FormField(
        label: 'Description (optional)',
        child: CupertinoTextField(
          controller: _descriptionController,
          placeholder: 'Why this goal matters to you…',
          padding: const EdgeInsets.all(AppSpacing.md),
          maxLines: 3,
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor4,
          ),
        ),
      );

  Widget _saveButton(BuildContext context, bool isEditing) =>
      CupertinoButton.filled(
        onPressed: _titleController.text.trim().isEmpty
            ? null
            : () async {
                final navigator = Navigator.of(context);
                try {
                  await widget.onSave(
                    _titleController.text.trim(),
                    _selectedCategory,
                    _descriptionController.text.trim(),
                    _priority,
                  );
                } finally {
                  if (navigator.canPop()) navigator.pop();
                }
              },
        child: Text(
          isEditing ? 'Save Changes' : 'Add Goal',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _cancelButton(BuildContext context) => CupertinoButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel',
            style: TextStyle(color: AppColors.textColor3)),
      );
}

class NoteFormSheet extends StatefulWidget {
  const NoteFormSheet({
    super.key,
    required this.availableGoals,
    this.initialNote,
    required this.onSave,
  });

  final List<FitnessGoal> availableGoals;
  final BackgroundNote? initialNote;
  final void Function(String content, NoteCategory category, String? goalId)
      onSave;

  @override
  State<NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends State<NoteFormSheet> {
  late final TextEditingController _contentController;
  late NoteCategory _selectedCategory;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.initialNote?.content ?? '',
    );
    _selectedCategory =
        widget.initialNote?.category ?? NoteCategory.preference;
    _selectedGoalId = widget.initialNote?.goalId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialNote != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragHandle(),
              const SizedBox(height: AppSpacing.lg),
              _sheetHeader(isEditing),
              const SizedBox(height: AppSpacing.xl),
              _contentField(),
              const SizedBox(height: AppSpacing.lg),
              _categoryField(),
              if (widget.availableGoals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _goalLinkField(),
              ],
              const SizedBox(height: AppSpacing.xl),
              _saveButton(isEditing),
              const SizedBox(height: AppSpacing.md),
              _cancelButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderDepth3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sheetHeader(bool isEditing) => Column(
        children: [
          Text(
            isEditing ? 'Edit Note' : 'New Background Note',
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add context about your body, preferences, or constraints.',
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _contentField() => _FormField(
        label: 'Note',
        child: CupertinoTextField(
          controller: _contentController,
          placeholder: 'e.g., Lower back sensitivity — avoid heavy axial loading',
          padding: const EdgeInsets.all(AppSpacing.md),
          maxLines: 4,
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor4,
          ),
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _categoryField() => _FormField(
        label: 'Category',
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: NoteCategory.values.mapL(_categoryChip),
        ),
      );

  Widget _categoryChip(NoteCategory cat) {
    final isSelected = cat == _selectedCategory;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary
              : AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDepth2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              cat.displayName,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? CupertinoColors.white
                    : AppColors.textColor2,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalLinkField() => _FormField(
        label: 'Link to Goal (optional)',
        child: Column(
          children: [
            _goalOption(id: null, label: 'General (all goals)', icon: CupertinoIcons.globe),
            const SizedBox(height: AppSpacing.sm),
            ...widget.availableGoals
                .where((goal) => goal.status == GoalStatus.active)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _goalOption(
                      id: goal.id,
                      label: goal.title,
                      icon: CupertinoIcons.flag_fill,
                    ),
                  ),
                ),
          ],
        ),
      );

  Widget _goalOption({
    required String? id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedGoalId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoalId = id),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.12)
              : AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDepth2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textColor3,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.textColor2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton(bool isEditing) => CupertinoButton.filled(
        onPressed: _contentController.text.trim().isEmpty
            ? null
            : () => widget.onSave(
                  _contentController.text.trim(),
                  _selectedCategory,
                  _selectedGoalId,
                ),
        child: Text(
          isEditing ? 'Save Changes' : 'Add Note',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _cancelButton(BuildContext context) => CupertinoButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel',
            style: TextStyle(color: AppColors.textColor3)),
      );
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
