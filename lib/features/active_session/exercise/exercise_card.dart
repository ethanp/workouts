import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/exercise/current_set_draft_controller.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_content.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

class ExerciseCard extends ConsumerStatefulWidget {
  const ExerciseCard({
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
    return ExerciseCardContent(
      planContext: planContext,
      isNextRecommended: widget.isNextRecommended,
      currentSetInput: _currentSetDraftController.currentInput(planContext),
      onCurrentSetChanged: _currentSetDraftController.update,
      onLogSet: _logSet,
      onUnlogSet: planContext.loggedSetCount == 0 ? null : _unlogSet,
      onTimerCompleted: _logSetAndAdvance,
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
}
