import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/background_note_row.dart';
import 'package:workouts/features/goals/background_notes_provider.dart';
import 'package:workouts/features/goals/goals_list_rows.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/goals/note_form_sheet.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';

class const BackgroundTab() extends ConsumerStatefulWidget {
  @override
  ConsumerState<BackgroundTab> createState() => _BackgroundTabState();
}

class _BackgroundTabState() extends ConsumerState<BackgroundTab> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);
    final notesAsync = ref.watch(backgroundNotesStreamProvider);

    return notesAsync.when(
      data: (notes) {
        final goals = goalsAsync.value ?? [];
        final activeNotes = notes.where((note) => note.isActive).toList();
        final archivedNotes = notes.where((note) => !note.isActive).toList();

        if (notes.isEmpty) {
          return _BackgroundEmptyState(
            onAddNote: () => _showAddNoteSheet(context, goals),
          );
        }

        return BackgroundNotesList(
          activeNotes: activeNotes,
          archivedNotes: archivedNotes,
          allGoals: goals,
          showArchived: _showArchived,
          onToggleArchived: () =>
              setState(() => _showArchived = !_showArchived),
          onAddNote: () => _showAddNoteSheet(context, goals),
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

  void _showAddNoteSheet(BuildContext context, List<FitnessGoal> goals) {
    final notesNotifier = ref.read(backgroundNotesControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => NoteFormSheet(
        availableGoals: goals,
        onSave: (content, category, goalId) {
          notesNotifier.addNote(
            content: content,
            category: category,
            goalId: goalId,
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class const BackgroundNotesList({
  required final List<BackgroundNote> activeNotes,
  required final List<BackgroundNote> archivedNotes,
  required final List<FitnessGoal> allGoals,
  required final bool showArchived,
  required final VoidCallback onToggleArchived,
  required final VoidCallback onAddNote,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceLg,
      vertical: ELayout.spaceMd,
    ).withOverlaidTabBar(context),
    children: [
      if (activeNotes.isNotEmpty) ...[
        GoalsSectionHeader(
          icon: Icons.description,
          title: 'BACKGROUND',
          action: TextButton(
            onPressed: onAddNote,
            child: const Text(
              'Add',
              style: TextStyle(fontSize: 14, color: EColors.accent),
            ),
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
        ...activeNotes.map(
          (note) => BackgroundNoteRow(note: note, allGoals: allGoals),
        ),
        const SizedBox(height: ELayout.spaceXl),
      ],
      if (archivedNotes.isNotEmpty) ...[
        GoalsArchivedToggleRow(
          count: archivedNotes.length,
          isExpanded: showArchived,
          onArchivedSectionToggled: onToggleArchived,
        ),
        if (showArchived) ...[
          const SizedBox(height: ELayout.spaceSm),
          ...archivedNotes.map(
            (note) => BackgroundNoteRow(
              note: note,
              allGoals: allGoals,
              isArchived: true,
            ),
          ),
        ],
      ],
      const SizedBox(height: 32),
    ],
  );
}

class const _BackgroundEmptyState({required final VoidCallback onAddNote})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.description,
                size: 32,
                color: EColors.accent,
              ),
            ),
            const SizedBox(height: ELayout.spaceXl),
            Text('No Background Notes', style: EText.title),
            const SizedBox(height: ELayout.spaceSm),
            Text(
              'Capture context the LLM should know — injuries, preferences, equipment, schedule.',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onAddNote,
              child: const Text(
                'Add Background Note',
                style: TextStyle(
                  color: Colors.white,
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
