import 'package:ethan_utils/ethan_utils.dart';

import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_calendar_day.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/session/session_exercise_store.dart';
import 'package:workouts/services/repositories/session/session_hydrator.dart';
import 'package:workouts/services/repositories/session/session_materializer.dart';
import 'package:workouts/services/repositories/session/session_set_log_store.dart';
import 'package:workouts/services/repositories/session_metrics_store.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'session_repository_powersync.g.dart';

const _log = ELogger('SessionRepository');

class SessionRepositoryPowerSync {
  SessionRepositoryPowerSync(this._powerSync, this._templateRepository) {
    _sessionHydrator = SessionHydrator(_powerSync);
    _setLogStore = SessionSetLogStore(_powerSync);
    _exerciseStore = SessionExerciseStore(
      _powerSync,
      _sessionHydrator,
      _setLogStore,
    );
    _materializer = SessionMaterializer(_powerSync, _templateRepository);
  }

  final PowerSyncDatabase _powerSync;
  final TemplateRepositoryPowerSync _templateRepository;
  late final SessionHydrator _sessionHydrator;
  late final SessionSetLogStore _setLogStore;
  late final SessionExerciseStore _exerciseStore;
  late final SessionMaterializer _materializer;
  late final SessionMetricsStore _metricsStore = SessionMetricsStore(
    _powerSync,
  );

  Future<Session> startSession(String templateId) =>
      _materializer.startSession(templateId);

  Future<void> logSet({
    required Session session,
    required SessionSetLog setLog,
  }) => _setLogStore.logSet(session: session, setLog: setLog);

  Future<void> unlogSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) =>
      _setLogStore.unlogSet(session: session, block: block, exercise: exercise);

  Future<Session> fetchSessionById(String sessionId) =>
      _sessionHydrator.fetchSessionById(sessionId);

  Future<List<Session>> fetchSessions() => _sessionHydrator.fetchSessions();

  Stream<List<Session>> watchSessions() => _sessionHydrator.watchSessions();

  Stream<List<SessionCalendarDay>> watchSessionCalendarDays() =>
      _sessionHydrator.watchSessionCalendarDays();

  Future<List<Session>> getSessionsForDate(DateTime localDate) =>
      _sessionHydrator.getSessionsForDate(localDate);

  Future<void> completeSession(
    Session session, {
    String? notes,
    String? feeling,
    TrainingLoadCalculator? trainingLoad,
  }) async {
    final completedAt = DateTime.now();
    final completedAtUtcText = completedAt.toUtc().toIso8601String();

    var activeDuration = completedAt.difference(session.startedAt);
    if (session.isPaused && session.pausedAt != null) {
      activeDuration -= DateTime.now().difference(session.pausedAt!);
    }
    activeDuration -= session.totalPausedDuration;

    final heartRateStats = await _powerSync.getAll(
      '''
      SELECT AVG(bpm) as avg_bpm, MAX(bpm) as max_bpm
      FROM heart_rate_samples
      WHERE session_id = ?
      ''',
      [session.id],
    );
    final avgBpm = heartRateStats.first['avg_bpm'] as num?;
    final maxBpm = heartRateStats.first['max_bpm'] as int?;

    await _powerSync.execute(
      '''
      UPDATE sessions
      SET completed_at = ?, duration_seconds = ?, notes = ?, paused_at = NULL,
          average_heart_rate = ?, max_heart_rate = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        completedAtUtcText,
        activeDuration.inSeconds,
        notes ?? '',
        avgBpm?.round(),
        maxBpm,
        completedAtUtcText,
        session.id,
      ],
    );

    if (trainingLoad != null) {
      await _metricsStore.computeAndStore(
        session.id,
        trainingLoad: trainingLoad,
      );
    }
  }

  Future<void> discardSession(String sessionId) async {
    await _powerSync.execute('DELETE FROM sessions WHERE id = ?', [sessionId]);
    _log.log('Deleted session $sessionId (queued for upload).');
  }

  Future<void> discardAllInProgressSessions() async {
    await _powerSync.execute('DELETE FROM sessions WHERE completed_at IS NULL');
  }

  Future<List<Session>> history() async {
    final sessions = await fetchSessions();

    sessions.sort((sessionA, sessionB) {
      if (sessionA.completedAt == null && sessionB.completedAt != null) {
        return -1;
      }
      if (sessionA.completedAt != null && sessionB.completedAt == null) {
        return 1;
      }
      if (sessionA.completedAt == null && sessionB.completedAt == null) {
        return sessionB.startedAt.compareTo(sessionA.startedAt);
      }
      return sessionB.completedAt!.compareTo(sessionA.completedAt!);
    });

    return sessions;
  }

  Future<void> pauseSession(Session session) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _powerSync.execute(
      'UPDATE sessions SET paused_at = ?, updated_at = ? WHERE id = ?',
      [now, now, session.id],
    );
  }

  Future<void> resumeSession(Session session) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (session.pausedAt == null) return;

    final pauseDuration = DateTime.now().difference(session.pausedAt!);
    final totalPausedDuration = session.totalPausedDuration + pauseDuration;

    await _powerSync.execute(
      '''
      UPDATE sessions
      SET paused_at = NULL, total_paused_duration_seconds = ?, updated_at = ?
      WHERE id = ?
      ''',
      [totalPausedDuration.inSeconds, now, session.id],
    );
  }

  Future<Session> addExercise(
    Session session,
    String blockId,
    WorkoutExercise exercise,
  ) => _exerciseStore.addExercise(session, blockId, exercise);

  Future<Session> removeExercise(
    Session session,
    String blockId,
    String exerciseId,
  ) => _exerciseStore.removeExercise(session, blockId, exerciseId);

  Future<void> recomputeZones({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) => _metricsStore.recomputeAllZones(
    trainingLoad: trainingLoad,
    onProgress: onProgress,
  );

  Future<void> backfillMissingMetrics({
    required TrainingLoadCalculator trainingLoad,
  }) => _metricsStore.backfillMissing(trainingLoad: trainingLoad);
}

@riverpod
SessionRepositoryPowerSync sessionRepositoryPowerSync(Ref ref) {
  final powerSync = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSync == null) {
    throw StateError('PowerSync database not initialized');
  }
  final templateRepository = ref.watch(templateRepositoryPowerSyncProvider);
  return SessionRepositoryPowerSync(powerSync, templateRepository);
}
