import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise_timer_panel.dart';

class ExerciseIntervalTimer extends StatefulWidget {
  const ExerciseIntervalTimer({
    super.key,
    required this.planContext,
    required this.isNextRecommended,
    required this.onCompleted,
  });

  final ExerciseSetPlanContext planContext;
  final bool isNextRecommended;
  final Future<void> Function() onCompleted;

  @override
  State<ExerciseIntervalTimer> createState() => _ExerciseIntervalTimerState();
}

class _ExerciseIntervalTimerState extends State<ExerciseIntervalTimer> {
  Timer? _timer;
  Duration? _remaining;
  TimerPhase _phase = TimerPhase.idle;
  bool _isPaused = false;
  int _lastObservedLoggedSetCount = 0;

  Duration get _setupDuration => widget.planContext.setupDuration;

  Duration get _workDuration => widget.planContext.workDuration;

  Duration get _restDuration => widget.planContext.restDuration;

  bool get _isRunningPhase =>
      _phase == TimerPhase.setup ||
      _phase == TimerPhase.work ||
      _phase == TimerPhase.rest;

  bool get _shouldAutoStartSetupOrWork =>
      widget.isNextRecommended && widget.planContext.hasSetupOrWorkTiming;

  bool get _isLastPlannedSet {
    final plannedSetCount = widget.planContext.plannedSetCount;
    if (plannedSetCount <= 0) return false;
    return widget.planContext.loggedSetCount >= plannedSetCount;
  }

  @override
  void initState() {
    super.initState();
    _lastObservedLoggedSetCount = widget.planContext.loggedSetCount;
    if (_shouldAutoStartSetupOrWork) _startInitialPhase();
  }

  @override
  void didUpdateWidget(covariant ExerciseIntervalTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startRestIfWarranted();
    _autoStartIfNewlyRecommended(oldWidget);
  }

  void _startRestIfWarranted() {
    final newLoggedSetCount = widget.planContext.loggedSetCount;
    final didLogSet = newLoggedSetCount > _lastObservedLoggedSetCount;
    _lastObservedLoggedSetCount = newLoggedSetCount;
    if (!didLogSet) return;
    if (_restDuration <= Duration.zero) return;
    if (_isLastPlannedSet) return;
    _startPhase(TimerPhase.rest);
  }

  /// Auto-start only when this card *transitions* into being the next
  /// recommended exercise (and the timer is sitting idle). Re-running on
  /// every parent rebuild is dangerous: the parent's elapsed-clock ticker
  /// fires `setState` once a second, and a blanket "if recommended, start"
  /// would clobber a manually-running timer. It would also re-start a
  /// timer the user just tapped Reset on, which is hostile.
  void _autoStartIfNewlyRecommended(ExerciseIntervalTimer oldWidget) {
    final bool wasRecommended =
        oldWidget.isNextRecommended && oldWidget.planContext.hasSetupOrWorkTiming;
    if (wasRecommended) return;
    if (!_shouldAutoStartSetupOrWork) return;
    if (_phase != TimerPhase.idle) return;
    _startInitialPhase();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExerciseTimerPanel(
      phase: _phase,
      remaining: _remaining,
      isPaused: _isPaused,
      onStart: _startInitialPhase,
      onPause: _pauseTimer,
      onResume: _resumeTimer,
      onReset: _resetTimer,
      onAdjustTime: _adjustTime,
      canPause: _isRunningPhase && !_isPaused,
      canResume: _isRunningPhase && _isPaused,
      canStart: !_isRunningPhase,
      canReset: _phase != TimerPhase.idle,
      canAdjust: _isRunningPhase,
      hasSetupPhase: _setupDuration > Duration.zero,
      hasWorkPhase: _workDuration > Duration.zero,
      hasRestPhase: _restDuration > Duration.zero,
    );
  }

  void _startInitialPhase() {
    if (!widget.planContext.hasTiming) return;
    final TimerPhase phase = _setupDuration > Duration.zero
        ? TimerPhase.setup
        : TimerPhase.work;
    if (phase == TimerPhase.work && _workDuration <= Duration.zero) return;
    _startPhase(phase);
  }

  void _startPhase(TimerPhase phase) {
    final Duration duration = _durationForPhase(phase);
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
    final Duration nextRemaining = _remaining! - const Duration(seconds: 1);
    if (nextRemaining <= Duration.zero) {
      _advancePhase(_phase);
      return;
    }
    setState(() => _remaining = nextRemaining);
  }

  void _advancePhase(TimerPhase phase) {
    if (phase == TimerPhase.setup && _workDuration > Duration.zero) {
      _startPhase(TimerPhase.work);
      return;
    }
    if (phase == TimerPhase.rest) {
      _endRestPhase();
      return;
    }
    _completeTimer();
  }

  void _completeTimer() {
    _timer?.cancel();
    setState(() {
      _phase = TimerPhase.complete;
      _isPaused = false;
      _remaining = Duration.zero;
    });
    unawaited(widget.onCompleted());
  }

  /// Ends a rest phase without logging another set. The set was already
  /// logged before rest started; rest is a recovery interval, not a
  /// completion event.
  void _endRestPhase() {
    _timer?.cancel();
    setState(() {
      _phase = TimerPhase.complete;
      _isPaused = false;
      _remaining = Duration.zero;
    });
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

  void _adjustTime(int seconds) {
    if (!_isRunningPhase || _remaining == null) return;
    setState(() {
      final Duration adjustedRemaining =
          _remaining! + Duration(seconds: seconds);
      _remaining = adjustedRemaining < Duration.zero
          ? Duration.zero
          : adjustedRemaining;
      if (_remaining == Duration.zero) _advancePhase(_phase);
    });
  }

  Duration _durationForPhase(TimerPhase phase) => switch (phase) {
    TimerPhase.setup => _setupDuration,
    TimerPhase.work => _workDuration,
    TimerPhase.rest => _restDuration,
    TimerPhase.idle || TimerPhase.complete => Duration.zero,
  };
}
