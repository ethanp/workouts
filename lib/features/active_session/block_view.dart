import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDragStartListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/block_progress.dart';
import 'package:workouts/features/library/exercise_picker_screen.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/features/active_session/exercise/dismissible_exercise_card.dart';

class BlockView extends ConsumerStatefulWidget {
  const BlockView({super.key, required this.block});

  final SessionBlock block;

  @override
  ConsumerState<BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends ConsumerState<BlockView> {
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      buildDefaultDragHandles: false,
      header: _stickyHeader(context, roundLabel: roundLabel),
      itemCount: widget.block.exercises.length,
      itemBuilder: (context, index) =>
          _exerciseItem(index, nextExerciseId: nextExerciseId),
      onReorder: _onReorder,
    );
  }

  Widget _stickyHeader(BuildContext context, {required String? roundLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _blockHeader(context),
        if (roundLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _roundBadge(roundLabel),
          const SizedBox(height: AppSpacing.md),
        ] else
          const SizedBox(height: AppSpacing.sm),
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

  void _onReorder(int oldIndex, int newIndex) {
    final reordered = [...widget.block.exercises];
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(adjustedNewIndex, moved);
    ref
        .read(activeSessionProvider.notifier)
        .reorderExercises(
          widget.block,
          reordered.map((exercise) => exercise.id).toList(),
        );
  }

  /// Pick the first exercise in this block that has unfinished sets and the
  /// user hasn't manually marked done. Mirrors `SessionBlock.nextIncompleteExercise`
  /// but layered with the ephemeral early-stopped flag so the timer
  /// auto-flow respects "I'm done with this one".
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
            style: AppTypography.title,
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(AppSpacing.xs),
          onPressed: () => _showExercisePicker(context),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              CupertinoIcons.add,
              color: AppColors.accentPrimary,
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth2),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
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
    final existingExerciseIds = widget.block.exercises
        .map((workoutExercise) => workoutExercise.id)
        .toSet();
    final exercise = await context.push<WorkoutExercise>(
      ExercisePickerScreen(excludeIds: existingExerciseIds),
    );
    if (mounted && exercise != null) {
      ref
          .read(activeSessionProvider.notifier)
          .addExercise(widget.block, exercise);
    }
  }
}

class _ExerciseDragHandle extends StatelessWidget {
  const _ExerciseDragHandle();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: Icon(
      CupertinoIcons.line_horizontal_3,
      size: 20,
      color: AppColors.textColor3,
    ),
  );
}
