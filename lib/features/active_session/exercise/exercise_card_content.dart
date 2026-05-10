import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/exercise/current_set_editor.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_actions.dart';
import 'package:workouts/features/active_session/exercise/exercise_interval_timer.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/expandable_cues.dart';

class ExerciseCardContent extends StatelessWidget {
  const ExerciseCardContent({
    super.key,
    required this.planContext,
    required this.isNextRecommended,
    required this.currentSetInput,
    required this.onCurrentSetChanged,
    required this.onLogSet,
    required this.onUnlogSet,
    required this.onTimerCompleted,
  });

  final ExerciseSetPlanContext planContext;
  final bool isNextRecommended;
  final SetLogInput currentSetInput;
  final ValueChanged<SetLogInput> onCurrentSetChanged;
  final VoidCallback onLogSet;
  final VoidCallback? onUnlogSet;
  final Future<void> Function() onTimerCompleted;

  WorkoutExercise get exercise => planContext.exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _exerciseHeader(),
          ..._exerciseDetails(),
          ..._currentSetEditorSection(),
          const SizedBox(height: AppSpacing.sm),
          _actionRow(),
          ..._timerSection(),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDepth1),
    );
  }

  List<Widget> _exerciseDetails() {
    return [
      if (exercise.restDuration != null) ...[
        const SizedBox(height: AppSpacing.xs),
        _restLabel(),
      ],
      if (exercise.cues.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        ExpandableCues(cues: exercise.cues),
      ],
      if (planContext.showsTimingWarning) ...[
        const SizedBox(height: AppSpacing.xs),
        _timingWarning(),
      ],
    ];
  }

  List<Widget> _currentSetEditorSection() {
    if (!planContext.showsCurrentSetEditor) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      CurrentSetEditor(
        key: ValueKey(planContext.setDraftKey),
        exercise: exercise,
        plannedSet: planContext.nextPlannedSet,
        initialInput: currentSetInput,
        onChanged: onCurrentSetChanged,
      ),
    ];
  }

  List<Widget> _timerSection() {
    if (!planContext.hasTiming) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      ExerciseIntervalTimer(
        planContext: planContext,
        isNextRecommended: isNextRecommended,
        onCompleted: onTimerCompleted,
      ),
    ];
  }

  Widget _exerciseHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(exercise.name, style: AppTypography.subtitle)),
        Text(exercise.prescriptionLabel, style: AppTypography.caption),
      ],
    );
  }

  Widget _restLabel() {
    return Text(
      'Rest: ${Format.restDuration(exercise.restDuration!)}',
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    );
  }

  Widget _timingWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Timer unavailable (old session). Start a new session for auto-timer.',
        style: AppTypography.caption.copyWith(color: AppColors.warning),
      ),
    );
  }

  Widget _actionRow() {
    return ExerciseCardActions(
      completedSetCount: planContext.loggedSetCount,
      plannedSetCount: planContext.plannedSetCount,
      nextPlannedSet: planContext.nextPlannedSet,
      onLogSet: onLogSet,
      onUnlogSet: onUnlogSet,
    );
  }
}
