import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/active_session/exercise/active_timer_store.dart';
import 'package:workouts/features/active_session/exercise/current_set_editor.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_actions.dart';
import 'package:workouts/features/active_session/exercise/exercise_card_menu_button.dart';
import 'package:workouts/features/active_session/exercise/exercise_interval_timer.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise/set_log_input.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/expandable_cues.dart';

class const ExerciseCardContent({
  /// Stable identity for the embedded interval timer's persisted record.
  required final TimerIdentity timerIdentity,
  required final ExerciseSetPlanContext planContext,
  required final bool isNextRecommended,
  required final SetLogInput currentSetInput,
  required final ValueChanged<SetLogInput> onCurrentSetChanged,
  required final VoidCallback onLogSet,
  required final VoidCallback? onUnlogSet,
  required final Future<void> Function() onTimerCompleted,
  final VoidCallback? onExerciseHistoryRequested,
  final VoidCallback? onAiCoachRequested,
  final VoidCallback? onExerciseSwapRequested,
  final VoidCallback? onAddWarmupSet,
  final VoidCallback? onRemoveWarmupSet,
  final bool isStoppedEarly = false,
  final VoidCallback? onToggleStoppedEarly,

  /// Opaque widget rendered in the header's icon cluster. The host (e.g.
  /// `BlockView`) supplies a `ReorderableDragStartListener` here when the
  /// card lives inside a `ReorderableListView`; otherwise null hides the
  /// affordance. This card knows nothing about reorder semantics.
  final Widget? dragHandle,
}) extends StatelessWidget {
  WorkoutExercise get exercise => planContext.exercise;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: ELayout.spaceMd),
    padding: const EdgeInsets.all(ELayout.spaceMd),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _exerciseHeader(),
        ..._exerciseDetails(),
        ..._completedSetsSection(),
        ..._currentSetEditorSection(),
        const SizedBox(height: ELayout.spaceSm),
        _actionRow(),
        ..._timerSection(),
      ],
    ),
  );

  BoxDecoration _cardDecoration() {
    if (planContext.isFullyLogged) {
      return BoxDecoration(
        color: EColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.success.withValues(alpha: 0.4)),
      );
    }
    if (isStoppedEarly) {
      return BoxDecoration(
        color: EColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.warning.withValues(alpha: 0.4)),
      );
    }
    return BoxDecoration(
      color: EColors.backgroundLift,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
      border: Border.all(color: EColors.border),
    );
  }

  List<Widget> _exerciseDetails() => [
    if (exercise.restDuration != null) ...[
      const SizedBox(height: ELayout.spaceXs),
      _restLabel(),
    ],
    if (exercise.cues.isNotEmpty) ...[
      const SizedBox(height: ELayout.spaceSm),
      ExpandableCues(cues: exercise.cues),
    ],
    if (planContext.showsTimingWarning) ...[
      const SizedBox(height: ELayout.spaceXs),
      _timingWarning(),
    ],
  ];

  List<Widget> _completedSetsSection() {
    final logs = planContext.exerciseLogs;
    if (logs.isEmpty) return const [];
    return [
      const SizedBox(height: ELayout.spaceSm),
      Text(
        'Completed',
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
      const SizedBox(height: ELayout.spaceXs),
      for (final log in logs) SessionSetLogRow(log: log, exercise: exercise),
    ];
  }

  List<Widget> _currentSetEditorSection() {
    if (!planContext.showsCurrentSetEditor) return const [];
    return [
      const SizedBox(height: ELayout.spaceSm),
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
      const SizedBox(height: ELayout.spaceMd),
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
      Expanded(child: Text(exercise.name, style: EText.section)),
      ExerciseCardMenuButton(
        exerciseName: exercise.name,
        onExerciseHistoryRequested: onExerciseHistoryRequested,
        onAiCoachRequested: onAiCoachRequested,
        onExerciseSwapRequested: onExerciseSwapRequested,
        onToggleStoppedEarly: _canToggleStoppedEarly
            ? onToggleStoppedEarly
            : null,
        isStoppedEarly: isStoppedEarly,
      ),
      if (dragHandle != null) dragHandle!,
      Text(exercise.prescriptionLabel, style: EText.caption),
    ],
  );

  /// The flag is only meaningful while the exercise isn't already fully
  /// logged — a green-decorated complete card has no use for an "early
  /// stopped" toggle. The host also opts in by wiring up the callback.
  bool get _canToggleStoppedEarly =>
      onToggleStoppedEarly != null && !planContext.isFullyLogged;

  Widget _restLabel() => Text(
    'Rest: ${Format.restDuration(exercise.restDuration!)}',
    style: EText.caption.copyWith(color: EColors.textTertiary),
  );

  Widget _timingWarning() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceSm,
      vertical: ELayout.spaceXs,
    ),
    decoration: BoxDecoration(
      color: EColors.warning.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(ELayout.radiusSm),
      border: Border.all(color: EColors.warning.withValues(alpha: 0.3)),
    ),
    child: Text(
      'Timer unavailable (old session). Start a new session for auto-timer.',
      style: EText.caption.copyWith(color: EColors.warning),
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
