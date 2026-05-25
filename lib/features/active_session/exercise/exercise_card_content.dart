import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/exercise/active_timer_store.dart';
import 'package:workouts/features/active_session/exercise/current_set_editor.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_actions.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_menu_button.dart';
import 'package:workouts/features/active_session/exercise/exercise_interval_timer.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/expandable_cues.dart';

class ExerciseCardContent extends StatelessWidget {
  const ExerciseCardContent({
    super.key,
    required this.timerIdentity,
    required this.planContext,
    required this.isNextRecommended,
    required this.currentSetInput,
    required this.onCurrentSetChanged,
    required this.onLogSet,
    required this.onUnlogSet,
    required this.onTimerCompleted,
    this.onReplacePressed,
    this.onHistoryPressed,
    this.onAskAiPressed,
    this.onAddWarmupSet,
    this.onRemoveWarmupSet,
    this.isStoppedEarly = false,
    this.onToggleStoppedEarly,
    this.dragHandle,
  });

  /// Stable identity for the embedded interval timer's persisted record.
  final TimerIdentity timerIdentity;
  final ExerciseSetPlanContext planContext;
  final bool isNextRecommended;
  final SetLogInput currentSetInput;
  final ValueChanged<SetLogInput> onCurrentSetChanged;
  final VoidCallback onLogSet;
  final VoidCallback? onUnlogSet;
  final Future<void> Function() onTimerCompleted;
  final VoidCallback? onReplacePressed;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onAskAiPressed;
  final VoidCallback? onAddWarmupSet;
  final VoidCallback? onRemoveWarmupSet;
  final bool isStoppedEarly;
  final VoidCallback? onToggleStoppedEarly;

  /// Opaque widget rendered in the header's icon cluster. The host (e.g.
  /// `BlockView`) supplies a `ReorderableDragStartListener` here when the
  /// card lives inside a `ReorderableListView`; otherwise null hides the
  /// affordance. This card knows nothing about reorder semantics.
  final Widget? dragHandle;

  WorkoutExercise get exercise => planContext.exercise;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _exerciseHeader(),
        ..._exerciseDetails(),
        ..._completedSetsSection(),
        ..._currentSetEditorSection(),
        const SizedBox(height: AppSpacing.sm),
        _actionRow(),
        ..._timerSection(),
      ],
    ),
  );

  BoxDecoration _cardDecoration() {
    if (planContext.isFullyLogged) {
      return BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      );
    }
    if (isStoppedEarly) {
      return BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      );
    }
    return BoxDecoration(
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDepth1),
    );
  }

  List<Widget> _exerciseDetails() => [
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

  List<Widget> _completedSetsSection() {
    final logs = planContext.exerciseLogs;
    if (logs.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Completed',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
      const SizedBox(height: AppSpacing.xs),
      for (final log in logs) SessionSetLogRow(log: log, exercise: exercise),
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
        currentSide: planContext.currentSideOfPair,
      ),
    ];
  }

  List<Widget> _timerSection() {
    if (!planContext.hasTiming) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      ExerciseIntervalTimer(
        identity: timerIdentity,
        planContext: planContext,
        isNextRecommended: isNextRecommended,
        onCompleted: onTimerCompleted,
      ),
    ];
  }

  Widget _exerciseHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(child: Text(exercise.name, style: AppTypography.subtitle)),
      ExerciseCardMenuButton(
        exerciseName: exercise.name,
        onHistoryPressed: onHistoryPressed,
        onAskAiPressed: onAskAiPressed,
        onReplacePressed: onReplacePressed,
        onToggleStoppedEarly: _canToggleStoppedEarly
            ? onToggleStoppedEarly
            : null,
        isStoppedEarly: isStoppedEarly,
      ),
      if (dragHandle != null) dragHandle!,
      Text(exercise.prescriptionLabel, style: AppTypography.caption),
    ],
  );

  /// The flag is only meaningful while the exercise isn't already fully
  /// logged — a green-decorated complete card has no use for an "early
  /// stopped" toggle. The host also opts in by wiring up the callback.
  bool get _canToggleStoppedEarly =>
      onToggleStoppedEarly != null && !planContext.isFullyLogged;

  Widget _restLabel() => Text(
    'Rest: ${Format.restDuration(exercise.restDuration!)}',
    style: AppTypography.caption.copyWith(color: AppColors.textColor3),
  );

  Widget _timingWarning() => Container(
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

  Widget _actionRow() => ExerciseCardActions(
    completedSetCount: planContext.loggedSetCount,
    plannedSetCount: planContext.plannedSetCount,
    nextPlannedSet: planContext.nextPlannedSet,
    onLogSet: onLogSet,
    onUnlogSet: onUnlogSet,
    onAddWarmupSet: planContext.warmupSets.canAdd ? onAddWarmupSet : null,
    onRemoveWarmupSet: planContext.warmupSets.canRemove
        ? onRemoveWarmupSet
        : null,
    sidesPerSet: exercise.sidesPerSet,
    currentSide: planContext.currentSideOfPair,
  );
}
