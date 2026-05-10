import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/exercise/exercise_card.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';

class DismissibleExerciseCard extends ConsumerWidget {
  const DismissibleExerciseCard({
    super.key,
    required this.block,
    required this.exercise,
    required this.isNextRecommended,
    required this.onSetLogged,
  });

  final SessionBlock block;
  final WorkoutExercise exercise;
  final bool isNextRecommended;
  final VoidCallback onSetLogged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLogs = block.logs.any(
      (sessionSetLog) => sessionSetLog.exerciseId == exercise.id,
    );

    return Dismissible(
      key: ValueKey('dismiss-${exercise.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndRemove(context, ref, hasLogs),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white),
      ),
      child: ExerciseCard(
        block: block,
        exercise: exercise,
        isNextRecommended: isNextRecommended,
        onSetLogged: onSetLogged,
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context, bool hasLogs) async {
    final String confirmationMessage = hasLogs
        ? 'This exercise has logged sets. Removing it will delete all progress for this exercise.'
        : 'Remove this exercise from the current block?';

    final bool? confirmedRemoval = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Remove Exercise?'),
        content: Text(confirmationMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirmedRemoval ?? false;
  }

  Future<bool> _confirmAndRemove(
    BuildContext context,
    WidgetRef ref,
    bool hasLogs,
  ) async {
    final ActiveSessionNotifier activeSessionNotifier = ref.read(
      activeSessionProvider.notifier,
    );
    final bool confirmedRemoval = await _confirmRemove(context, hasLogs);
    if (!confirmedRemoval) return false;
    if (!context.mounted) return false;

    await activeSessionNotifier.removeExercise(block, exercise.id);
    return false;
  }
}
