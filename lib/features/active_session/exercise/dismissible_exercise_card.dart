import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/exercise/exercise_card.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

class const DismissibleExerciseCard({
  required final SessionBlock block,
  required final WorkoutExercise exercise,
  required final bool isNextRecommended,
  required final VoidCallback onSetLogged,
  final Widget? dragHandle,

  /// Key attached to an inner subtree (not to the widget itself). The host
  /// list owns the outer `key:` (e.g. ReorderableListView's required item
  /// key); `wrapperKey` lets `Scrollable.ensureVisible` still target the
  /// card via a stable per-exercise GlobalKey.
  final Key? wrapperKey,
}) extends ConsumerWidget {
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
        margin: const EdgeInsets.only(bottom: ELayout.spaceMd),
        padding: const EdgeInsets.only(right: ELayout.spaceLg),
        decoration: BoxDecoration(
          color: EColors.danger,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: KeyedSubtree(
        key: wrapperKey,
        child: ExerciseCard(
          block: block,
          exercise: exercise,
          isNextRecommended: isNextRecommended,
          onSetLogged: onSetLogged,
          dragHandle: dragHandle,
        ),
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context, bool hasLogs) async {
    final String confirmationMessage = hasLogs
        ? 'This exercise has logged sets. Removing it will delete all progress for this exercise.'
        : 'Remove this exercise from the current block?';

    final bool? confirmedRemoval = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Exercise?'),
        content: Text(confirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
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
