import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/background_notes_provider.dart';
import 'package:workouts/features/goals/note_form_sheet.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class const BackgroundNoteRow({
  required final BackgroundNote note,
  required final List<FitnessGoal> allGoals,
  final bool isArchived = false,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedGoal = note.goalId != null
        ? allGoals.where((goal) => goal.id == note.goalId).firstOrNull
        : null;
    final categoryColor = _categoryColor(note.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
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
              horizontal: ELayout.spaceMd,
              vertical: ELayout.spaceSm,
            ),
            decoration: BoxDecoration(
              color: EColors.backgroundLift,
              borderRadius: BorderRadius.circular(ELayout.radiusSm),
              border: Border.all(
                color: isArchived
                    ? EColors.border.withValues(alpha: 0.4)
                    : EColors.border,
              ),
            ),
            child: Row(
              children: [
                Text(note.category.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: ELayout.spaceMd),
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
      color: EColors.danger,
      borderRadius: BorderRadius.circular(ELayout.radiusSm),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: ELayout.spaceLg),
    child: const Icon(
      Icons.delete,
      color: Colors.white,
      size: 22,
    ),
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
    style: EText.body.medium.copyWith(
      color: isArchived ? EColors.textTertiary : EColors.textSecondary,
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
        horizontal: ELayout.spaceXs + 2,
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
    const SizedBox(width: ELayout.spaceSm),
    const Icon(Icons.link, size: 11, color: EColors.textMuted),
    const SizedBox(width: 2),
    Flexible(
      child: Text(
        linkedGoal.title,
        style: EText.caption.copyWith(
          fontSize: 11,
          color: EColors.textMuted,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ];

  void _showActions(BuildContext context, WidgetRef ref) {
    final notesNotifier = ref.read(backgroundNotesControllerProvider.notifier);
    final preview = note.content.length > 50
        ? '${note.content.substring(0, 50)}…'
        : note.content;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(preview)),
            ..._noteActionSheetActions(sheetCtx, context, ref, notesNotifier),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetCtx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _noteActionSheetActions(
    BuildContext sheetCtx,
    BuildContext parentCtx,
    WidgetRef ref,
    BackgroundNotesController notesNotifier,
  ) {
    return [
      ListTile(
        title: const Text('Edit'),
        onTap: () {
          Navigator.of(sheetCtx).pop();
          _showEditSheet(parentCtx, ref);
        },
      ),
      if (note.isActive)
        ListTile(
          title: const Text('Archive'),
          onTap: () {
            Navigator.of(sheetCtx).pop();
            notesNotifier.archiveNote(note.id);
          },
        ),
      if (!note.isActive)
        ListTile(
          title: const Text('Reactivate'),
          onTap: () {
            Navigator.of(sheetCtx).pop();
            notesNotifier.activateNote(note.id);
          },
        ),
      ListTile(
        title: Text('Delete', style: TextStyle(color: EColors.danger)),
        onTap: () {
          Navigator.of(sheetCtx).pop();
          notesNotifier.deleteNote(note.id);
        },
      ),
    ];
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final notesNotifier = ref.read(backgroundNotesControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => NoteFormSheet(
        availableGoals: allGoals,
        initialNote: note,
        onSave: (content, category, goalId) {
          notesNotifier.updateNote(
            note.copyWith(content: content, category: category, goalId: goalId),
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Color _categoryColor(NoteCategory category) {
    return switch (category) {
      NoteCategory.injuryHistory => EColors.danger,
      NoteCategory.avoid => EColors.warning,
      NoteCategory.medical => EColors.danger,
      NoteCategory.preference => EColors.warning,
      NoteCategory.equipment => EColors.accent,
      NoteCategory.constraint => EColors.warning,
      NoteCategory.philosophy => EColors.success,
    };
  }
}
