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

  Duration get _setupDuration => widget.planContext.setupDuration;

  Duration get _workDuration => widget.planContext.workDuration;

  bool get _isRunningPhase =>
      _phase == TimerPhase.setup || _phase == TimerPhase.work;

  bool get _shouldAutoStart =>
      widget.isNextRecommended && widget.planContext.hasTiming;

  @override
  void initState() {
    super.initState();
    if (_shouldAutoStart) _startInitialPhase();
  }

  @override
  void didUpdateWidget(covariant ExerciseIntervalTimer oldWidget) {
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
    return ExerciseTimerPanel(
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
      canSkip: _phase != TimerPhase.idle && _phase != TimerPhase.complete,
      hasSetupPhase: _setupDuration > Duration.zero,
      hasWorkPhase: _workDuration > Duration.zero,
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
    unawaited(widget.onCompleted());
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
    TimerPhase.idle || TimerPhase.complete => Duration.zero,
  };
}
