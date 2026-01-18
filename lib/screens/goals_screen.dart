import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/providers/background_notes_provider.dart';
import 'package:workouts/providers/goals_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsStreamProvider);
    final notesAsync = ref.watch(backgroundNotesStreamProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: const SyncStatusIcon(),
        middle: const Text('Goals & Context'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddMenu(context, ref),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: goalsAsync.when(
          data: (goals) {
            final notes = notesAsync.value ?? [];
            if (goals.isEmpty && notes.isEmpty) {
              return _EmptyState(
                onAddGoal: () => _showAddGoalSheet(context, ref),
                onAddNote: () => _showAddNoteSheet(context, ref, goals),
              );
            }
            return _ContentList(goals: goals, notes: notes);
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Error: $error',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    final goals = ref.read(goalsStreamProvider).value ?? [];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAddGoalSheet(context, ref);
            },
            child: const Text('Add Goal'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAddNoteSheet(context, ref, goals);
            },
            child: const Text('Add Background Note'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _GoalFormSheet(
        onSave: (title, category, description, priority) {
          ref
              .read(goalsControllerProvider.notifier)
              .addGoal(
                title: title,
                category: category,
                description: description,
                priority: priority,
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showAddNoteSheet(
    BuildContext context,
    WidgetRef ref,
    List<FitnessGoal> goals,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _NoteFormSheet(
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddGoal, required this.onAddNote});

  final VoidCallback onAddGoal;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                CupertinoIcons.sparkles,
                size: 40,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Build Your Context', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add goals and background notes to help personalize your training.',
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
            const SizedBox(height: AppSpacing.md),
            CupertinoButton(
              onPressed: onAddNote,
              child: Text(
                'Or add a background note',
                style: TextStyle(color: AppColors.accentPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentList extends ConsumerWidget {
  const _ContentList({required this.goals, required this.notes});

  final List<FitnessGoal> goals;
  final List<BackgroundNote> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGoals = goals
        .where((g) => g.status == GoalStatus.active)
        .toList();
    final archivedGoals = goals
        .where((g) => g.status != GoalStatus.active)
        .toList();
    final activeNotes = notes.where((n) => n.isActive).toList();
    final archivedNotes = notes.where((n) => !n.isActive).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (activeGoals.isNotEmpty) ...[
          _SectionHeader(title: 'GOALS', icon: CupertinoIcons.flag_fill),
          const SizedBox(height: AppSpacing.sm),
          ...activeGoals.map((goal) => _GoalTile(goal: goal, allGoals: goals)),
        ],
        if (activeNotes.isNotEmpty) ...[
          SizedBox(height: activeGoals.isNotEmpty ? AppSpacing.xl : 0),
          _SectionHeader(
            title: 'BACKGROUND',
            icon: CupertinoIcons.doc_text_fill,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...activeNotes.map((note) => _NoteTile(note: note, goals: goals)),
        ],
        if (archivedGoals.isNotEmpty || archivedNotes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          _SectionHeader(title: 'ARCHIVED', icon: CupertinoIcons.archivebox),
          const SizedBox(height: AppSpacing.sm),
          ...archivedGoals.map(
            (goal) => _GoalTile(goal: goal, allGoals: goals),
          ),
          ...archivedNotes.map((note) => _NoteTile(note: note, goals: goals)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppColors.textColor4),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          title,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile({required this.goal, this.allGoals = const []});

  final FitnessGoal goal;
  final List<FitnessGoal> allGoals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = goal.status == GoalStatus.active;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _showGoalActions(context, ref),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isActive
                  ? AppColors.borderDepth1
                  : AppColors.borderDepth1.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _categoryColor(goal.category).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(
                    '${goal.priority}',
                    style: TextStyle(
                      color: _categoryColor(goal.category),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: AppTypography.subtitle.copyWith(
                        color: isActive
                            ? AppColors.textColor1
                            : AppColors.textColor3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _CategoryBadge(category: goal.category),
                        if (goal.status == GoalStatus.achieved) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ],
                        if (goal.status == GoalStatus.paused) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            CupertinoIcons.pause_circle,
                            size: 14,
                            color: AppColors.textColor4,
                          ),
                        ],
                      ],
                    ),
                    if (goal.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        goal.description,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textColor4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.textColor4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalActions(BuildContext context, WidgetRef ref) {
    final isActive = goal.status == GoalStatus.active;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(goal.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditSheet(context, ref);
            },
            child: const Text('Edit'),
          ),
          if (isActive)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(goalsControllerProvider.notifier)
                    .markAchieved(goal.id);
              },
              child: const Text('Mark as Achieved'),
            ),
          if (isActive)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(goalsControllerProvider.notifier).archiveGoal(goal.id);
              },
              child: const Text('Archive'),
            ),
          if (!isActive)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(goalsControllerProvider.notifier)
                    .activateGoal(goal.id);
              },
              child: const Text('Reactivate'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(goalsControllerProvider.notifier).deleteGoal(goal.id);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _GoalFormSheet(
        initialGoal: goal,
        onSave: (title, category, description, priority) {
          ref
              .read(goalsControllerProvider.notifier)
              .updateGoal(
                goal.copyWith(
                  title: title,
                  category: category,
                  description: description,
                  priority: priority,
                  updatedAt: DateTime.now(),
                ),
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Color _categoryColor(GoalCategory category) {
    return switch (category) {
      GoalCategory.strength || GoalCategory.power => AppColors.error,
      GoalCategory.endurance || GoalCategory.quickness => AppColors.warning,
      GoalCategory.mobility ||
      GoalCategory.balance ||
      GoalCategory.coordination => AppColors.accentSecondary,
      GoalCategory.physique || GoalCategory.posture => AppColors.accentPrimary,
      GoalCategory.rehabilitation ||
      GoalCategory.longevity => AppColors.success,
      GoalCategory.skill => AppColors.textColor2,
    };
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final GoalCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatCategory(category),
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          color: AppColors.textColor3,
        ),
      ),
    );
  }

  String _formatCategory(GoalCategory category) {
    return category.name
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .toLowerCase();
  }
}

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({this.initialGoal, required this.onSave});

  final FitnessGoal? initialGoal;
  final void Function(
    String title,
    GoalCategory category,
    String description,
    int priority,
  )
  onSave;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late GoalCategory _selectedCategory;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialGoal?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialGoal?.description ?? '',
    );
    _selectedCategory = widget.initialGoal?.category ?? GoalCategory.strength;
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDepth3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isEditing ? 'Edit Goal' : 'New Goal',
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _FormField(
                label: 'Title',
                child: CupertinoTextField(
                  controller: _titleController,
                  placeholder: 'e.g., Improve posture',
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDepth3,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textColor1,
                  ),
                  placeholderStyle: AppTypography.body.copyWith(
                    color: AppColors.textColor4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormField(
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
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormField(
                label: 'Priority (1 = highest)',
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
                              color: isSelected
                                  ? CupertinoColors.white
                                  : AppColors.textColor2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormField(
                label: 'Description (optional)',
                child: CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: 'Why this goal matters to you...',
                  padding: const EdgeInsets.all(AppSpacing.md),
                  maxLines: 3,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDepth3,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textColor1,
                  ),
                  placeholderStyle: AppTypography.body.copyWith(
                    color: AppColors.textColor4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              CupertinoButton.filled(
                onPressed: _titleController.text.trim().isEmpty
                    ? null
                    : () => widget.onSave(
                        _titleController.text.trim(),
                        _selectedCategory,
                        _descriptionController.text.trim(),
                        _priority,
                      ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Add Goal',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textColor3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note, required this.goals});

  final BackgroundNote note;
  final List<FitnessGoal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedGoal = note.goalId != null
        ? goals.where((g) => g.id == note.goalId).firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _showNoteActions(context, ref),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: note.isActive
                  ? AppColors.borderDepth1
                  : AppColors.borderDepth1.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _categoryColor(note.category).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(
                    note.category.icon,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.content,
                      style: AppTypography.body.copyWith(
                        color: note.isActive
                            ? AppColors.textColor1
                            : AppColors.textColor3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor(
                              note.category,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            note.category.displayName,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              color: _categoryColor(note.category),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (linkedGoal != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            CupertinoIcons.link,
                            size: 12,
                            color: AppColors.textColor4,
                          ),
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
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteActions(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          note.content.length > 50
              ? '${note.content.substring(0, 50)}...'
              : note.content,
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditSheet(context, ref);
            },
            child: const Text('Edit'),
          ),
          if (note.isActive)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(backgroundNotesControllerProvider.notifier)
                    .archiveNote(note.id);
              },
              child: const Text('Archive'),
            ),
          if (!note.isActive)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(backgroundNotesControllerProvider.notifier)
                    .activateNote(note.id);
              },
              child: const Text('Reactivate'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(backgroundNotesControllerProvider.notifier)
                  .deleteNote(note.id);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _NoteFormSheet(
        availableGoals: goals,
        initialNote: note,
        onSave: (content, category, goalId) {
          ref
              .read(backgroundNotesControllerProvider.notifier)
              .updateNote(
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

class _NoteFormSheet extends StatefulWidget {
  const _NoteFormSheet({
    required this.availableGoals,
    this.initialNote,
    required this.onSave,
  });

  final List<FitnessGoal> availableGoals;
  final BackgroundNote? initialNote;
  final void Function(String content, NoteCategory category, String? goalId)
  onSave;

  @override
  State<_NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends State<_NoteFormSheet> {
  late TextEditingController _contentController;
  late NoteCategory _selectedCategory;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.initialNote?.content ?? '',
    );
    _selectedCategory = widget.initialNote?.category ?? NoteCategory.preference;
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDepth3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isEditing ? 'Edit Note' : 'New Background Note',
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add context about your body, preferences, or constraints.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _FormField(
                label: 'Note',
                child: CupertinoTextField(
                  controller: _contentController,
                  placeholder:
                      'e.g., Lower back sensitivity - avoid heavy axial loading',
                  padding: const EdgeInsets.all(AppSpacing.md),
                  maxLines: 4,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDepth3,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textColor1,
                  ),
                  placeholderStyle: AppTypography.body.copyWith(
                    color: AppColors.textColor4,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormField(
                label: 'Category',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: NoteCategory.values.map((cat) {
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
                            Text(
                              cat.icon,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              cat.displayName,
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
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (widget.availableGoals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _FormField(
                  label: 'Link to Goal (optional)',
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedGoalId = null),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: _selectedGoalId == null
                                ? AppColors.accentPrimary.withValues(
                                    alpha: 0.15,
                                  )
                                : AppColors.backgroundDepth3,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: _selectedGoalId == null
                                  ? AppColors.accentPrimary
                                  : AppColors.borderDepth2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.globe,
                                size: 16,
                                color: _selectedGoalId == null
                                    ? AppColors.accentPrimary
                                    : AppColors.textColor3,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'General (applies to all goals)',
                                style: TextStyle(
                                  color: _selectedGoalId == null
                                      ? AppColors.accentPrimary
                                      : AppColors.textColor2,
                                  fontWeight: _selectedGoalId == null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...widget.availableGoals
                          .where((g) => g.status == GoalStatus.active)
                          .map((goal) {
                            final isSelected = _selectedGoalId == goal.id;
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedGoalId = goal.id),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accentPrimary.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.backgroundDepth3,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentPrimary
                                          : AppColors.borderDepth2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.flag_fill,
                                        size: 16,
                                        color: isSelected
                                            ? AppColors.accentPrimary
                                            : AppColors.textColor3,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          goal.title,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppColors.accentPrimary
                                                : AppColors.textColor2,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              CupertinoButton.filled(
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
              ),
              const SizedBox(height: AppSpacing.md),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textColor3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
