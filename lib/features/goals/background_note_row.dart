import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/background_notes_provider.dart';
import 'package:workouts/features/goals/note_form_sheet.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class BackgroundNoteRow extends ConsumerWidget {
  const BackgroundNoteRow({
    super.key,
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
        ? allGoals.where((goal) => goal.id == note.goalId).firstOrNull
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

  Future<bool> _confirmDelete(BuildContext context) => confirmDeleteDialog(
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
        child: const Icon(CupertinoIcons.trash,
            color: CupertinoColors.white, size: 22),
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
    final notesNotifier =
        ref.read(backgroundNotesControllerProvider.notifier);
    final preview = note.content.length > 50
        ? '${note.content.substring(0, 50)}…'
        : note.content;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: Text(preview),
        actions:
            _noteActionSheetActions(sheetCtx, context, ref, notesNotifier),
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
    BackgroundNotesController notesNotifier,
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
            notesNotifier.archiveNote(note.id);
          },
          child: const Text('Archive'),
        ),
      if (!note.isActive)
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(sheetCtx).pop();
            notesNotifier.activateNote(note.id);
          },
          child: const Text('Reactivate'),
        ),
      CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.of(sheetCtx).pop();
          notesNotifier.deleteNote(note.id);
        },
        child: const Text('Delete'),
      ),
    ];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final notesNotifier =
        ref.read(backgroundNotesControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => NoteFormSheet(
        availableGoals: allGoals,
        initialNote: note,
        onSave: (content, category, goalId) {
          notesNotifier.updateNote(
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
