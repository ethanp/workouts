import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/background_note_row.dart';
import 'package:workouts/features/goals/background_notes_provider.dart';
import 'package:workouts/features/goals/goals_list_chrome.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/goals/note_form_sheet.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class BackgroundTab extends ConsumerStatefulWidget {
  const BackgroundTab({super.key});

  @override
  ConsumerState<BackgroundTab> createState() => _BackgroundTabState();
}

class _BackgroundTabState extends ConsumerState<BackgroundTab> {
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
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  void _showAddNoteSheet(BuildContext context, List<FitnessGoal> goals) {
    final notesNotifier = ref.read(backgroundNotesControllerProvider.notifier);
    showCupertinoModalPopup<void>(
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

class BackgroundNotesList extends StatelessWidget {
  const BackgroundNotesList({
    super.key,
    required this.activeNotes,
    required this.archivedNotes,
    required this.allGoals,
    required this.showArchived,
    required this.onToggleArchived,
    required this.onAddNote,
  });

  final List<BackgroundNote> activeNotes;
  final List<BackgroundNote> archivedNotes;
  final List<FitnessGoal> allGoals;
  final bool showArchived;
  final VoidCallback onToggleArchived;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    children: [
      if (activeNotes.isNotEmpty) ...[
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
      ],
      if (archivedNotes.isNotEmpty) ...[
        GoalsArchivedToggleRow(
          count: archivedNotes.length,
          isExpanded: showArchived,
          onTap: onToggleArchived,
        ),
        if (showArchived) ...[
          const SizedBox(height: AppSpacing.sm),
          ...archivedNotes.map(
            (note) => BackgroundNoteRow(
              note: note,
              allGoals: allGoals,
              isArchived: true,
            ),
          ),
        ],
      ],
      const SizedBox(height: AppSpacing.xxl),
    ],
  );
}

class _BackgroundEmptyState extends StatelessWidget {
  const _BackgroundEmptyState({required this.onAddNote});

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                CupertinoIcons.doc_text_fill,
                size: 32,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('No Background Notes', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Capture context the LLM should know — injuries, preferences, equipment, schedule.',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            CupertinoButton.filled(
              onPressed: onAddNote,
              child: const Text(
                'Add Background Note',
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
