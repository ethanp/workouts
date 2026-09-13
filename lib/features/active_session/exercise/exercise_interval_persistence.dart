import 'dart:async';

import 'package:workouts/features/active_session/exercise/active_timer_store.dart';
import 'package:workouts/features/active_session/exercise_timer_panel.dart';
import 'package:workouts/services/notifications/timer_notification_service.dart';

/// Timer records older than this on launch are dropped — matches the
/// `fetchResumableSession` staleness rule so a forgotten timer from
/// yesterday never auto-fires anything on the next session.
const Duration exerciseIntervalMaxRestoreAge = Duration(hours: 12);

class const ExerciseIntervalRestoreDecision({
  final ActiveTimerRecord? record,
  final bool advanceExpired = false,
}) {
  static const none = ExerciseIntervalRestoreDecision();

  bool get shouldRestore => record != null;
}

/// Store + notification side of [ExerciseIntervalTimer]: write/clear the
/// quit-surviving record and schedule the matching local notification.
class ExerciseIntervalPersistence({
  required final ActiveTimerStore store,
  required final TimerNotificationService notifications,
  required final TimerIdentity identity,
}) {
  ExerciseIntervalRestoreDecision decideRestore() {
    final record = store.read();
    if (record == null) return ExerciseIntervalRestoreDecision.none;
    if (record.sessionId != identity.sessionId) {
      clear();
      return ExerciseIntervalRestoreDecision.none;
    }
    if (!identity.matches(record)) {
      return ExerciseIntervalRestoreDecision.none;
    }
    if (_isStale(record)) {
      clear();
      return ExerciseIntervalRestoreDecision.none;
    }
    final expired =
        !record.isPaused &&
        record.endsAt != null &&
        !DateTime.now().isBefore(record.endsAt!);
    return ExerciseIntervalRestoreDecision(
      record: record,
      advanceExpired: expired,
    );
  }

  void persistRunning({required TimerPhase phase, required DateTime endsAt}) {
    unawaited(
      store.write(
        ActiveTimerRecord(
          sessionId: identity.sessionId,
          blockId: identity.blockId,
          exerciseId: identity.exerciseId,
          phase: phase,
          endsAt: endsAt,
        ),
      ),
    );
  }

  void persistPaused({
    required TimerPhase phase,
    required Duration pausedRemaining,
  }) {
    unawaited(
      store.write(
        ActiveTimerRecord(
          sessionId: identity.sessionId,
          blockId: identity.blockId,
          exerciseId: identity.exerciseId,
          phase: phase,
          pausedRemaining: pausedRemaining,
        ),
      ),
    );
  }

  void clear() {
    unawaited(store.clear());
    unawaited(notifications.cancel());
  }

  void cancelNotification() {
    unawaited(notifications.cancel());
  }

  void scheduleNotification({
    required TimerPhase phase,
    required DateTime endsAt,
    required String exerciseName,
  }) {
    unawaited(
      notifications.scheduleAt(
        endsAt: endsAt,
        body: notificationBody(phase: phase, exerciseName: exerciseName),
      ),
    );
  }

  static String notificationBody({
    required TimerPhase phase,
    required String exerciseName,
  }) {
    return switch (phase) {
      TimerPhase.rest => '$exerciseName: rest is up',
      TimerPhase.work => "$exerciseName: time's up",
      TimerPhase.setup => '$exerciseName: setup complete',
      TimerPhase.idle || TimerPhase.complete => exerciseName,
    };
  }

  bool _isStale(ActiveTimerRecord record) {
    final DateTime? endsAt = record.endsAt;
    if (endsAt == null) return false;
    return DateTime.now().difference(endsAt) > exerciseIntervalMaxRestoreAge;
  }
}
