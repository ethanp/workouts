import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/exercise/active_exercise_timer_provider.dart';
import 'package:workouts/features/active_session/exercise/active_timer_store.dart';
import 'package:workouts/features/active_session/exercise/active_timer_store_provider.dart';
import 'package:workouts/features/active_session/exercise/exercise_set_plan_context.dart';
import 'package:workouts/features/active_session/exercise_timer_panel.dart';
import 'package:workouts/services/notifications/timer_notification_service.dart';
import 'package:workouts/services/notifications/timer_notification_service_provider.dart';

/// Timer records older than this on launch are dropped — matches the
/// `fetchResumableSession` staleness rule so a forgotten timer from
/// yesterday never auto-fires anything on the next session.
const Duration _maxRestoreAge = Duration(hours: 12);

class ExerciseIntervalTimer extends ConsumerStatefulWidget {
  const ExerciseIntervalTimer({
    super.key,
    required this.identity,
    required this.planContext,
    required this.isNextRecommended,
    required this.onCompleted,
  });

  /// Locates this card's record in [ActiveTimerStore]. The store holds at
  /// most one record (single-active-timer invariant); only the card whose
  /// identity matches the persisted record will restore from it.
  final TimerIdentity identity;

  final ExerciseSetPlanContext planContext;
  final bool isNextRecommended;
  final Future<void> Function() onCompleted;

  @override
  ConsumerState<ExerciseIntervalTimer> createState() =>
      _ExerciseIntervalTimerState();
}

/// Countdown that survives an iOS background/lock by anchoring the
/// running phase to a wall-clock end-time, and survives an outright app
/// quit by mirroring its state to [ActiveTimerStore] and scheduling a
/// matching local notification via [TimerNotificationService].
///
/// Three layers of robustness, in order of severity:
/// - Foreground: a 1 Hz repaint ticker just rebuilds the UI; the
///   displayed value is always `endsAt - now`.
/// - Background / screen lock: `WidgetsBindingObserver` catches up the
///   display the moment the app resumes, and auto-advances the phase if
///   it expired while we were gone.
/// - Full app quit: the persisted record + scheduled notification cover
///   it. On the next launch, [initState] reads the record, restores the
///   phase, and either resumes live ticking or runs the same advance
///   path the resume hook would.
class _ExerciseIntervalTimerState extends ConsumerState<ExerciseIntervalTimer>
    with WidgetsBindingObserver {
  /// Opaque token identifying this timer instance for the session-wide
  /// single-active-timer coordinator. Lifetime matches this State.
  final Object _ownerToken = Object();

  Timer? _ticker;

  /// Wall-clock instant the current phase will complete. Null when the
  /// timer is idle, paused, or complete. Source of truth while running.
  DateTime? _endsAt;

  /// Remaining duration captured at pause. Null whenever the timer isn't
  /// paused. Source of truth while paused.
  Duration? _pausedRemaining;

  TimerPhase _phase = TimerPhase.idle;
  int _lastObservedLoggedSetCount = 0;

  /// Cached notifier reference captured during initState so the dispose
  /// path can release the active-timer slot without touching `ref`.
  /// Riverpod prohibits `ref.read` once the widget is being unmounted —
  /// the official guidance is to stash provider notifiers in a field.
  late final ActiveExerciseTimer _activeExerciseTimerNotifier;

  Duration get _setupDuration => widget.planContext.setupDuration;

  Duration get _workDuration => widget.planContext.workDuration;

  Duration get _restDuration => widget.planContext.restDuration;

  bool get _isPaused => _pausedRemaining != null;

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

  ActiveTimerStore get _store => ref.read(activeTimerStoreProvider);

  TimerNotificationService get _notif =>
      ref.read(timerNotificationServiceProvider);

  /// Live remaining duration derived from wall-clock state. Returns
  /// `Duration.zero` (not a negative value) once we're past `_endsAt` so
  /// the UI can render `00:00` while the next tick's `_advancePhase`
  /// fires.
  Duration? _liveRemaining() {
    if (_pausedRemaining != null) return _pausedRemaining;
    if (_endsAt == null) return null;
    final Duration delta = _endsAt!.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastObservedLoggedSetCount = widget.planContext.loggedSetCount;
    _activeExerciseTimerNotifier = ref.read(
      activeExerciseTimerProvider.notifier,
    );
    if (_restoreFromStore()) return;
    if (_shouldAutoStartSetupOrWork) {
      _scheduleAutoStart(_startInitialPhase);
    }
  }

  @override
  void didUpdateWidget(covariant ExerciseIntervalTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startRestIfWarranted();
    _autoStartIfNewlyRecommended(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_isRunningPhase || _isPaused) return;
    // Either the phase expired while we were backgrounded — advance now —
    // or it didn't, and we just need a repaint with the catch-up value.
    if (_endsAt != null && !DateTime.now().isBefore(_endsAt!)) {
      _advancePhase(_phase);
      return;
    }
    setState(() {});
  }

  void _startRestIfWarranted() {
    final newLoggedSetCount = widget.planContext.loggedSetCount;
    final didLogSet = newLoggedSetCount > _lastObservedLoggedSetCount;
    _lastObservedLoggedSetCount = newLoggedSetCount;
    if (!didLogSet) return;
    if (_restDuration <= Duration.zero) return;
    if (_isLastPlannedSet) return;
    _scheduleAutoStart(() => _startPhase(TimerPhase.rest));
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
    _scheduleAutoStart(_startInitialPhase);
  }

  /// Defers the active-timer-slot claim to after the current frame.
  /// Used from `_restoreFromStore`, which runs from `initState` — a
  /// forbidden lifecycle for provider mutations.
  void _scheduleClaim() {
    final notifier = _activeExerciseTimerNotifier;
    final token = _ownerToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifier.claim(token);
    });
  }

  /// Auto-start work fires from build-phase lifecycles (initState,
  /// didUpdateWidget) — both forbidden contexts for `ref.read(...).claim()`
  /// because the provider mutation propagates synchronously to other
  /// watchers that may be mid-build. Deferring to the next frame puts the
  /// claim cleanly after the build commit, matching what
  /// `_restoreFromStore` already does for expired-phase advancement.
  void _scheduleAutoStart(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Mutating activeExerciseTimerProvider here would synchronously
    // notify peer ExerciseIntervalTimers, but during a session-UI
    // dismount those peers are themselves mid-dispose. The
    // notification leaves the framework's dependent bookkeeping in an
    // inconsistent state (`_dependents.isEmpty` assertion fails) and
    // the next session re-open then collides with the half-torn-down
    // tree. Use the notifier captured in initState (ref is unsafe in
    // dispose) and release after the dispose cascade settles.
    final notifier = _activeExerciseTimerNotifier;
    final token = _ownerToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.release(token);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reset ourselves whenever another timer claims the active slot. The
    // listener fires after this build commits, so calling _resetTimer
    // (which calls setState) inside is safe.
    ref.listen<Object?>(activeExerciseTimerProvider, (previous, next) {
      if (next == null) return;
      if (identical(next, _ownerToken)) return;
      if (!_isRunningPhase) return;
      _resetTimer();
    });

    return ExerciseTimerPanel(
      phase: _phase,
      remaining: _liveRemaining(),
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

  /// Loads the persisted record (if any) and applies it to this state.
  /// Returns true iff the record matched this card and was restored —
  /// callers use that to skip auto-start (since the restored state takes
  /// precedence).
  bool _restoreFromStore() {
    final ActiveTimerRecord? record = _store.read();
    if (record == null) return false;
    if (record.sessionId != widget.identity.sessionId) {
      // Stale leftover from a different session — clear it for everyone.
      unawaited(_store.clear());
      unawaited(_notif.cancel());
      return false;
    }
    if (!widget.identity.matches(record)) {
      // Belongs to a sibling card; that card's State will pick it up.
      return false;
    }
    if (_isStaleRecord(record)) {
      unawaited(_store.clear());
      unawaited(_notif.cancel());
      return false;
    }
    // initState is a forbidden lifecycle for provider mutations. Stage
    // local state synchronously here and defer the actual claim to the
    // next frame so peer ExerciseIntervalTimers' build/initState aren't
    // notified mid-build.
    _scheduleClaim();
    _phase = record.phase;
    if (record.isPaused) {
      _pausedRemaining = record.pausedRemaining;
      _endsAt = null;
      return true;
    }
    _endsAt = record.endsAt;
    _pausedRemaining = null;
    if (_endsAt != null && !DateTime.now().isBefore(_endsAt!)) {
      // Phase expired while we were dead. Schedule the same advance path
      // the resume hook uses — including the auto-log for work/setup —
      // after this frame so the surrounding session UI is settled.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _advancePhase(_phase);
      });
      return true;
    }
    _startTicker();
    return true;
  }

  bool _isStaleRecord(ActiveTimerRecord record) {
    final DateTime? endsAt = record.endsAt;
    if (endsAt == null) return false;
    return DateTime.now().difference(endsAt) > _maxRestoreAge;
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
    ref.read(activeExerciseTimerProvider.notifier).claim(_ownerToken);
    final DateTime endsAt = DateTime.now().add(duration);
    setState(() {
      _phase = phase;
      _pausedRemaining = null;
      _endsAt = endsAt;
    });
    _startTicker();
    _persistRunning(phase: phase, endsAt: endsAt);
    _scheduleNotification(phase: phase, endsAt: endsAt);
  }

  /// 1 Hz repaint pulse. Wall-clock arithmetic against `_endsAt` is what
  /// computes the displayed value — this exists only to schedule rebuilds
  /// and to detect expiry while the app is foregrounded.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted || _isPaused || _endsAt == null) return;
    if (!DateTime.now().isBefore(_endsAt!)) {
      _advancePhase(_phase);
      return;
    }
    setState(() {});
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
    _ticker?.cancel();
    ref.read(activeExerciseTimerProvider.notifier).release(_ownerToken);
    setState(() {
      _phase = TimerPhase.complete;
      _pausedRemaining = null;
      _endsAt = null;
    });
    _clearPersisted();
    unawaited(widget.onCompleted());
  }

  /// Ends a rest phase without logging another set. The set was already
  /// logged before rest started; rest is a recovery interval, not a
  /// completion event.
  void _endRestPhase() {
    _ticker?.cancel();
    ref.read(activeExerciseTimerProvider.notifier).release(_ownerToken);
    setState(() {
      _phase = TimerPhase.complete;
      _pausedRemaining = null;
      _endsAt = null;
    });
    _clearPersisted();
  }

  void _pauseTimer() {
    if (!_isRunningPhase || _isPaused) return;
    _ticker?.cancel();
    final Duration paused = _liveRemaining() ?? Duration.zero;
    setState(() {
      _pausedRemaining = paused;
      _endsAt = null;
    });
    _persistPaused(phase: _phase, pausedRemaining: paused);
    unawaited(_notif.cancel());
  }

  void _resumeTimer() {
    if (!_isRunningPhase || !_isPaused) return;
    final DateTime endsAt = DateTime.now().add(_pausedRemaining!);
    setState(() {
      _endsAt = endsAt;
      _pausedRemaining = null;
    });
    _startTicker();
    _persistRunning(phase: _phase, endsAt: endsAt);
    _scheduleNotification(phase: _phase, endsAt: endsAt);
  }

  void _resetTimer() {
    _ticker?.cancel();
    ref.read(activeExerciseTimerProvider.notifier).release(_ownerToken);
    setState(() {
      _phase = TimerPhase.idle;
      _pausedRemaining = null;
      _endsAt = null;
    });
    _clearPersisted();
  }

  void _adjustTime(int seconds) {
    if (!_isRunningPhase) return;
    final Duration delta = Duration(seconds: seconds);
    if (_isPaused) {
      final Duration adjusted = _pausedRemaining! + delta;
      if (adjusted <= Duration.zero) {
        _advancePhase(_phase);
        return;
      }
      setState(() => _pausedRemaining = adjusted);
      _persistPaused(phase: _phase, pausedRemaining: adjusted);
      return;
    }
    if (_endsAt == null) return;
    final DateTime adjustedEndsAt = _endsAt!.add(delta);
    if (!DateTime.now().isBefore(adjustedEndsAt)) {
      _advancePhase(_phase);
      return;
    }
    setState(() => _endsAt = adjustedEndsAt);
    _persistRunning(phase: _phase, endsAt: adjustedEndsAt);
    _scheduleNotification(phase: _phase, endsAt: adjustedEndsAt);
  }

  Duration _durationForPhase(TimerPhase phase) => switch (phase) {
    TimerPhase.setup => _setupDuration,
    TimerPhase.work => _workDuration,
    TimerPhase.rest => _restDuration,
    TimerPhase.idle || TimerPhase.complete => Duration.zero,
  };

  void _persistRunning({required TimerPhase phase, required DateTime endsAt}) {
    unawaited(_store.write(ActiveTimerRecord(
      sessionId: widget.identity.sessionId,
      blockId: widget.identity.blockId,
      exerciseId: widget.identity.exerciseId,
      phase: phase,
      endsAt: endsAt,
    )));
  }

  void _persistPaused({
    required TimerPhase phase,
    required Duration pausedRemaining,
  }) {
    unawaited(_store.write(ActiveTimerRecord(
      sessionId: widget.identity.sessionId,
      blockId: widget.identity.blockId,
      exerciseId: widget.identity.exerciseId,
      phase: phase,
      pausedRemaining: pausedRemaining,
    )));
  }

  void _clearPersisted() {
    unawaited(_store.clear());
    unawaited(_notif.cancel());
  }

  void _scheduleNotification({
    required TimerPhase phase,
    required DateTime endsAt,
  }) {
    unawaited(_notif.scheduleAt(
      endsAt: endsAt,
      body: _notificationBody(phase),
    ));
  }

  String _notificationBody(TimerPhase phase) {
    final String exerciseName = widget.planContext.exercise.name;
    return switch (phase) {
      TimerPhase.rest => '$exerciseName: rest is up',
      TimerPhase.work => "$exerciseName: time's up",
      TimerPhase.setup => '$exerciseName: setup complete',
      TimerPhase.idle || TimerPhase.complete => exerciseName,
    };
  }
}
