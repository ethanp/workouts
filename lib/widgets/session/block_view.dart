import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/screens/exercise_picker_screen.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/session/exercise_card.dart';

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
    final nextExerciseId = widget.block.nextIncompleteExercise?.id;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _blockHeader(context),
        if (roundLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _roundBadge(roundLabel),
          const SizedBox(height: AppSpacing.md),
        ] else
          const SizedBox(height: AppSpacing.sm),
        ...widget.block.exercises.map(
          (exercise) => DismissibleExerciseCard(
            key: _exerciseKeys[exercise.id],
            block: widget.block,
            exercise: exercise,
            isNextRecommended: exercise.id == nextExerciseId,
            onSetLogged: () => _scrollToNext(exercise.id),
          ),
        ),
      ],
    );
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
      (e) => e.id == currentExerciseId,
    );
    if (currentIndex >= 0 &&
        currentIndex < widget.block.exercises.length - 1) {
      _scrollToExercise(widget.block.exercises[currentIndex + 1].id);
    }
  }

  Future<void> _showExercisePicker(BuildContext context) async {
    final existingIds = widget.block.exercises.map((e) => e.id).toSet();
    final exercise = await context.push<WorkoutExercise>(
      (_) => ExercisePickerScreen(excludeIds: existingIds),
    );
    if (mounted && exercise != null) {
      ref
          .read(activeSessionProvider.notifier)
          .addExercise(widget.block, exercise);
    }
  }
}
