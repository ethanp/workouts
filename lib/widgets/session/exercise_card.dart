import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/expandable_cues.dart';
import 'package:workouts/widgets/session/exercise_timer_panel.dart';

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
    final hasLogs = block.logs.any((l) => l.exerciseId == exercise.id);

    return Dismissible(
      key: ValueKey('dismiss-${exercise.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemove(context, hasLogs),
      onDismissed: (_) {
        ref
            .read(activeSessionProvider.notifier)
            .removeExercise(block, exercise.id);
      },
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
    if (!hasLogs) return true;

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove Exercise?'),
        content: const Text(
          'This exercise has logged sets. Removing it will delete all progress for this exercise.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

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
  Timer? _timer;
  Duration? _remaining;
  TimerPhase _phase = TimerPhase.idle;
  bool _isPaused = false;

  Duration get _setupDuration =>
      widget.exercise.setupDuration ?? Duration.zero;

  Duration get _workDuration =>
      widget.exercise.workDuration ?? Duration.zero;

  bool get _hasTiming =>
      _setupDuration > Duration.zero || _workDuration > Duration.zero;

  bool get _isRunningPhase =>
      _phase == TimerPhase.setup || _phase == TimerPhase.work;

  bool get _shouldAutoStart => widget.isNextRecommended && _hasTiming;

  SessionBlock get block => widget.block;
  WorkoutExercise get exercise => widget.exercise;

  @override
  void initState() {
    super.initState();
    if (_shouldAutoStart) _startInitialPhase();
  }

  @override
  void didUpdateWidget(covariant ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAutoStart && !_isRunningPhase) {
      _startInitialPhase();
    } else if (!_shouldAutoStart && _phase != TimerPhase.idle) {
      _resetTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _exerciseHeader(),
          if (exercise.restDuration != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rest: ${Format.restDuration(exercise.restDuration!)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
          if (exercise.cues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpandableCues(cues: exercise.cues),
          ],
          if (_showTimingWarning) ...[
            const SizedBox(height: AppSpacing.xs),
            _timingWarning(),
          ],
          const SizedBox(height: AppSpacing.sm),
          _actionRow(),
          if (_hasTiming) ...[
            const SizedBox(height: AppSpacing.md),
            ExerciseTimerPanel(
              phase: _phase,
              remaining: _remaining,
              isPaused: _isPaused,
              onStart: _startInitialPhase,
              onPause: _pauseTimer,
              onResume: _resumeTimer,
              onReset: _resetTimer,
              onSkipToComplete: _skipToComplete,
              onAdjustTime: _adjustTime,
              canPause: _isRunningPhase && !_isPaused,
              canResume: _isRunningPhase && _isPaused,
              canStart: !_isRunningPhase,
              canReset: _phase != TimerPhase.idle,
              canAdjust: _isRunningPhase,
              canSkip:
                  _phase != TimerPhase.idle && _phase != TimerPhase.complete,
              hasSetupPhase: _setupDuration > Duration.zero,
              hasWorkPhase: _workDuration > Duration.zero,
            ),
          ],
        ],
      ),
    );
  }

  bool get _showTimingWarning {
    final expectedTiming =
        exercise.modality == ExerciseModality.timed &&
        exercise.prescription.contains('setup');
    return expectedTiming && !_hasTiming;
  }

  int get _loggedSets =>
      block.logs.where((log) => log.exerciseId == exercise.id).length;

  Widget _exerciseHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(exercise.name, style: AppTypography.subtitle)),
        Text(exercise.prescription, style: AppTypography.caption),
      ],
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
    final completedSets = _loggedSets;
    final targetSets = exercise.targetSets;
    final isComplete = targetSets > 0 && completedSets >= targetSets;

    return Row(
      children: [
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          onPressed: () => _logSet(context, ref),
          child: const Text(
            'Log Set',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: AppColors.backgroundDepth3,
          disabledColor: AppColors.backgroundDepth4,
          borderRadius: BorderRadius.circular(AppRadius.md),
          onPressed: _loggedSets == 0 ? null : () => _unlogSet(context, ref),
          child: const Text(
            'Unlog',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        _progressBadge(completedSets, targetSets, isComplete),
      ],
    );
  }

  Widget _progressBadge(int completed, int target, bool isComplete) {
    final background = isComplete
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.backgroundDepth3;
    final border = isComplete
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.borderDepth2;
    final textColor = isComplete ? AppColors.success : AppColors.textColor3;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Text(
        '$completed of $target completed',
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _logSet(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionProvider.notifier)
        .logSet(block: block, exercise: exercise, reps: 1);
  }

  Future<void> _unlogSet(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionProvider.notifier)
        .unlogSet(block: block, exercise: exercise);
  }

  void _startInitialPhase() {
    if (!_hasTiming) return;
    final phase = _setupDuration > Duration.zero
        ? TimerPhase.setup
        : TimerPhase.work;
    if (phase == TimerPhase.work && _workDuration <= Duration.zero) return;
    _startPhase(phase);
  }

  void _startPhase(TimerPhase phase) {
    final duration = _durationForPhase(phase);
    if (duration <= Duration.zero) {
      _advancePhase(phase);
      return;
    }
    setState(() {
      _phase = phase;
      _isPaused = false;
      _remaining = duration;
    });
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted || _isPaused || _remaining == null) return;
    final next = _remaining! - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      _advancePhase(_phase);
    } else {
      setState(() => _remaining = next);
    }
  }

  void _advancePhase(TimerPhase phase) {
    if (phase == TimerPhase.setup && _workDuration > Duration.zero) {
      _startPhase(TimerPhase.work);
    } else {
      _completeTimer();
    }
  }

  void _completeTimer() {
    _timer?.cancel();
    setState(() {
      _phase = TimerPhase.complete;
      _isPaused = false;
      _remaining = Duration.zero;
    });
    _logSetAndAdvance();
  }

  void _pauseTimer() {
    if (!_isRunningPhase || _isPaused) return;
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resumeTimer() {
    if (!_isRunningPhase || !_isPaused) return;
    setState(() => _isPaused = false);
    _startTicker();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _phase = TimerPhase.idle;
      _isPaused = false;
      _remaining = null;
    });
  }

  void _skipToComplete() {
    _timer?.cancel();
    setState(() {
      _phase = TimerPhase.complete;
      _isPaused = false;
      _remaining = Duration.zero;
    });
    _logSetAndAdvance();
  }

  Future<void> _logSetAndAdvance() async {
    await _logSet(context, ref);
    widget.onSetLogged();
  }

  void _adjustTime(int seconds) {
    if (!_isRunningPhase || _remaining == null) return;
    setState(() {
      final adjusted = _remaining! + Duration(seconds: seconds);
      _remaining = adjusted < Duration.zero ? Duration.zero : adjusted;
      if (_remaining == Duration.zero) _advancePhase(_phase);
    });
  }

  Duration _durationForPhase(TimerPhase phase) => switch (phase) {
    TimerPhase.setup => _setupDuration,
    TimerPhase.work => _workDuration,
    TimerPhase.idle || TimerPhase.complete => Duration.zero,
  };
}
