import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/early_stopped_notifier.dart';
import 'package:workouts/features/active_session/exercise/current_set_draft_controller.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_content.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/features/active_session/exercise_chat/exercise_chat_screen.dart';
import 'package:workouts/features/active_session/exercise_history/exercise_history_screen.dart';
import 'package:workouts/features/active_session/replace_exercise/replace_exercise_picker_screen.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/widgets/replace_confirmation_dialog.dart';

class ExerciseCard extends ConsumerStatefulWidget {
  const ExerciseCard({
    super.key,
    required this.block,
    required this.exercise,
    required this.isNextRecommended,
    required this.onSetLogged,
    this.dragHandle,
  });

  final SessionBlock block;
  final WorkoutExercise exercise;
  final bool isNextRecommended;
  final VoidCallback onSetLogged;
  final Widget? dragHandle;

  @override
  ConsumerState<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<ExerciseCard> {
  final _currentSetDraftController = CurrentSetDraftController();

  SessionBlock get block => widget.block;

  WorkoutExercise get exercise => widget.exercise;

  ExerciseSetPlanContext get _planContext =>
      ExerciseSetPlanContext(block: block, exercise: exercise);

  @override
  void initState() {
    super.initState();
    _syncCurrentSetDraft();
  }

  @override
  void didUpdateWidget(covariant ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCurrentSetDraft();
  }

  @override
  Widget build(BuildContext context) {
    final ExerciseSetPlanContext planContext = _syncedPlanContext();
    final Set<String> earlyStopped = ref.watch(earlyStoppedProvider);
    final bool isStoppedEarly = earlyStopped.contains(
      earlyStoppedKey(blockId: block.id, exerciseId: exercise.id),
    );
    return ExerciseCardContent(
      planContext: planContext,
      isNextRecommended: widget.isNextRecommended,
      currentSetInput: _currentSetDraftController.currentInput(planContext),
      onCurrentSetChanged: _currentSetDraftController.update,
      onLogSet: _logSet,
      onUnlogSet: planContext.loggedSetCount == 0 ? null : _unlogSet,
      onTimerCompleted: _logSetAndAdvance,
      onReplacePressed: _runReplaceFlow,
      onHistoryPressed: _openHistory,
      onAskAiPressed: _openAskAi,
      onAddWarmupSet: _addWarmupSet,
      onRemoveWarmupSet: _removeWarmupSet,
      isStoppedEarly: isStoppedEarly,
      onToggleStoppedEarly: _toggleStoppedEarly,
      dragHandle: widget.dragHandle,
    );
  }

  Future<void> _addWarmupSet() => ref
      .read(activeSessionProvider.notifier)
      .addWarmupSet(block, exercise);

  Future<void> _removeWarmupSet() => ref
      .read(activeSessionProvider.notifier)
      .removeWarmupSet(block, exercise);

  void _toggleStoppedEarly() {
    ref
        .read(earlyStoppedProvider.notifier)
        .toggle(blockId: block.id, exerciseId: exercise.id);
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => ExerciseHistoryScreen(exercise: exercise),
      ),
    );
  }

  void _openAskAi() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => ExerciseChatScreen(exercise: exercise),
      ),
    );
  }

  ExerciseSetPlanContext _syncedPlanContext() {
    final ExerciseSetPlanContext planContext = _planContext;
    _currentSetDraftController.syncToContext(planContext);
    return planContext;
  }

  Future<void> _logSet() async {
    final ActiveSessionNotifier activeSessionNotifier = ref.read(
      activeSessionProvider.notifier,
    );
    final ExerciseSetPlanContext planContext = _syncedPlanContext();
    final SetLogInput setLogInput = _currentSetDraftController.inputForLogging(
      planContext,
    );
    await activeSessionNotifier.logSet(
      block: block,
      exercise: exercise,
      weight: setLogInput.weight,
      reps: setLogInput.reps,
      duration: setLogInput.duration,
      unitRemaining: setLogInput.unitRemaining,
    );
  }

  void _syncCurrentSetDraft() {
    _currentSetDraftController.syncToContext(_planContext);
  }

  Future<void> _unlogSet() async {
    final ActiveSessionNotifier activeSessionNotifier = ref.read(
      activeSessionProvider.notifier,
    );
    await activeSessionNotifier.unlogSet(block: block, exercise: exercise);
  }

  Future<void> _logSetAndAdvance() async {
    await _logSet();
    widget.onSetLogged();
  }

  Future<void> _runReplaceFlow() async {
    final NavigatorState navigator = Navigator.of(context);
    final ActiveSessionNotifier activeSessionNotifier = ref.read(
      activeSessionProvider.notifier,
    );
    final excludeIds = block.exercises.map((blockExercise) => blockExercise.id).toSet();

    final WorkoutExercise? replacement = await navigator.push<WorkoutExercise>(
      CupertinoPageRoute(
        builder: (_) => ReplaceExercisePickerScreen(
          originalExercise: exercise,
          excludeIds: excludeIds,
        ),
      ),
    );
    if (replacement == null || !mounted) return;

    final Session? activeSession = ref.read(activeSessionProvider).value;
    if (activeSession == null) return;

    final int discardedLogCount = activeSession
        .loggedSetCountForExerciseAcrossSiblings(
          target: block,
          exerciseId: exercise.id,
        );
    if (discardedLogCount > 0) {
      final int affectedBlockCount = activeSession.siblingBlockCountOf(block);
      final bool confirmed = await confirmReplaceWithLogs(
        context,
        loggedSetCount: discardedLogCount,
        affectedBlockCount: affectedBlockCount,
      );
      if (!confirmed || !mounted) return;
    }

    await activeSessionNotifier.replaceExercise(
      block,
      exercise.id,
      replacement,
    );
  }
}
