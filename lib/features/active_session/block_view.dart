import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/block_progress.dart';
import 'package:workouts/features/library/exercise_picker_screen.dart';
import 'package:workouts/features/active_session/exercise/dismissible_exercise_card.dart';

class const BlockView({required final SessionBlock block})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<BlockView> createState() => _BlockViewState();
}

class _BlockViewState() extends ConsumerState<BlockView> {
  final _scrollController = ScrollController();
  final _exerciseKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    for (final exercise in widget.block.exercises) {
      _exerciseKeys[exercise.id] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant BlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final exercise in widget.block.exercises) {
      _exerciseKeys.putIfAbsent(exercise.id, () => GlobalKey());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRoundInfo =
        widget.block.roundIndex != null && widget.block.totalRounds != null;
    final roundLabel = hasRoundInfo
        ? 'Round ${widget.block.roundIndex} of ${widget.block.totalRounds}'
        : null;
    final nextExerciseId = _nextRecommendedExerciseId();

    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: const EdgeInsets.all(ELayout.spaceLg),
      buildDefaultDragHandles: false,
      header: _stickyHeader(context, roundLabel: roundLabel),
      itemCount: widget.block.exercises.length,
      itemBuilder: (context, index) =>
          _exerciseItem(index, nextExerciseId: nextExerciseId),
      onReorderItem: _persistExerciseOrder,
    );
  }

  Widget _stickyHeader(BuildContext context, {required String? roundLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _blockHeader(context),
        if (roundLabel != null) ...[
          const SizedBox(height: ELayout.spaceXs),
          _roundBadge(roundLabel),
          const SizedBox(height: ELayout.spaceMd),
        ] else
          const SizedBox(height: ELayout.spaceSm),
      ],
    );
  }

  Widget _exerciseItem(int index, {required String? nextExerciseId}) {
    final exercise = widget.block.exercises[index];
    return KeyedSubtree(
      key: ValueKey('reorder-${exercise.id}'),
      child: DismissibleExerciseCard(
        wrapperKey: _exerciseKeys[exercise.id],
        block: widget.block,
        exercise: exercise,
        isNextRecommended: exercise.id == nextExerciseId,
        onSetLogged: () => _scrollToNext(exercise.id),
        dragHandle: ReorderableDragStartListener(
          index: index,
          child: const _ExerciseDragHandle(),
        ),
      ),
    );
  }

  void _persistExerciseOrder(int oldIndex, int newIndex) {
    final reordered = [...widget.block.exercises];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    ref
        .read(activeSessionProvider.notifier)
        .reorderExercises(
          widget.block,
          reordered.map((exercise) => exercise.id).toList(),
        );
  }

  /// Pick the first exercise in this block with unfinished sets that the
  /// user hasn't flagged early-stopped, so the timer auto-flow respects
  /// "I'm done with this one".
  String? _nextRecommendedExerciseId() {
    return ref
        .watch(blockProgressProvider(widget.block))
        .firstUnfinishedExercise()
        ?.id;
  }

  Widget _blockHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.block.type.name.titleCase,
            style: EText.title,
          ),
        ),
        InkWell(
          onTap: () => _showExercisePicker(context),
          child: Container(
            padding: const EdgeInsets.all(ELayout.spaceSm),
            decoration: BoxDecoration(
              color: EColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(ELayout.radiusSm),
              border: Border.all(
                color: EColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.add,
              color: EColors.accent,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundBadge(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceMd,
          vertical: ELayout.spaceXs,
        ),
        decoration: BoxDecoration(
          color: EColors.surface,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.borderStrong),
        ),
        child: Text(
          label,
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _scrollToExercise(String exerciseId) {
    final key = _exerciseKeys[exerciseId];
    if (key?.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      });
    }
  }

  void _scrollToNext(String currentExerciseId) {
    final currentIndex = widget.block.exercises.indexWhere(
      (workoutExercise) => workoutExercise.id == currentExerciseId,
    );
    if (currentIndex >= 0 && currentIndex < widget.block.exercises.length - 1) {
      _scrollToExercise(widget.block.exercises[currentIndex + 1].id);
    }
  }

  Future<void> _showExercisePicker(BuildContext context) async {
    final exercise = await context.push<WorkoutExercise>(
      ExercisePickerScreen(excludeIds: widget.block.exerciseIds),
    );
    if (mounted && exercise != null) {
      ref
          .read(activeSessionProvider.notifier)
          .addExercise(widget.block, exercise);
    }
  }
}

class const _ExerciseDragHandle() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: ELayout.spaceSm),
    child: Icon(
      Icons.drag_handle,
      size: 20,
      color: EColors.textTertiary,
    ),
  );
}
