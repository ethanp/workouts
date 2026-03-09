import 'dart:async';

import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_calendar_day.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_mappers.dart' as mappers;
import 'package:workouts/services/repositories/session_metrics_store.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'session_repository_powersync.g.dart';

const _uuid = Uuid();
final _log = Logger('SessionRepository');

class SessionRepositoryPowerSync {
  SessionRepositoryPowerSync(this._powerSync, this._templateRepository);

  final PowerSyncDatabase _powerSync;
  final TemplateRepositoryPowerSync _templateRepository;
  late final SessionMetricsStore _metricsStore =
      SessionMetricsStore(_powerSync);

  Future<Session> startSession(String templateId) async {
    final List<WorkoutTemplate> templates =
        await _templateRepository.fetchTemplates();
    final WorkoutTemplate template =
        templates.firstWhere((item) => item.id == templateId);

    final String sessionId = _uuid.v4();
    final String now = DateTime.now().toIso8601String();

    await _insertSessionRow(sessionId, templateId, now);
    final List<SessionBlock> blocks =
        await _materializeBlocks(sessionId, template.blocks);

    return Session(
      id: sessionId,
      templateId: templateId,
      startedAt: DateTime.now(),
      blocks: blocks,
    );
  }

  Future<void> _insertSessionRow(
    String sessionId,
    String templateId,
    String now,
  ) => _powerSync.execute(
    '''
    INSERT INTO sessions (
      id, template_id, started_at, paused_at, total_paused_duration_seconds,
      updated_at
    ) VALUES (?, ?, ?, NULL, 0, ?)
    ''',
    [sessionId, templateId, now, now],
  );

  Future<List<SessionBlock>> _materializeBlocks(
    String sessionId,
    List<WorkoutBlock> templateBlocks,
  ) async {
    final List<SessionBlock> sessionBlocks = [];
    var blockIndex = 0;

    for (final WorkoutBlock templateBlock in templateBlocks) {
      final int totalRounds =
          templateBlock.rounds <= 0 ? 1 : templateBlock.rounds;
      final bool hasMultipleRounds = totalRounds > 1;

      for (var roundIndex = 0; roundIndex < totalRounds; roundIndex++) {
        final SessionBlock block = await _materializeSingleBlock(
          sessionId: sessionId,
          templateBlock: templateBlock,
          blockIndex: blockIndex,
          roundIndex: roundIndex,
          totalRounds: totalRounds,
          hasMultipleRounds: hasMultipleRounds,
        );
        sessionBlocks.add(block);
        blockIndex++;
      }
    }

    return sessionBlocks;
  }

  Future<SessionBlock> _materializeSingleBlock({
    required String sessionId,
    required WorkoutBlock templateBlock,
    required int blockIndex,
    required int roundIndex,
    required int totalRounds,
    required bool hasMultipleRounds,
  }) async {
    final String blockId = _uuid.v4();

    await _powerSync.execute(
      '''
      INSERT INTO session_blocks (
        id, session_id, block_index, type, target_duration_seconds,
        notes, round_index, total_rounds
      ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
      ''',
      [
        blockId,
        sessionId,
        blockIndex,
        templateBlock.type.name,
        templateBlock.targetDuration.inSeconds,
        hasMultipleRounds ? roundIndex + 1 : null,
        hasMultipleRounds ? totalRounds : null,
      ],
    );

    await _insertBlockExercises(blockId, templateBlock.exercises);

    return SessionBlock(
      id: blockId,
      sessionId: sessionId,
      type: templateBlock.type,
      blockIndex: blockIndex,
      exercises: templateBlock.exercises,
      logs: const [],
      targetDuration: templateBlock.targetDuration,
      roundIndex: hasMultipleRounds ? roundIndex + 1 : null,
      totalRounds: hasMultipleRounds ? totalRounds : null,
    );
  }

  Future<void> _insertBlockExercises(
    String blockId,
    List<WorkoutExercise> exercises,
  ) async {
    for (var exerciseIndex = 0;
        exerciseIndex < exercises.length;
        exerciseIndex++) {
      final WorkoutExercise exercise = exercises[exerciseIndex];
      await _powerSync.execute(
        '''
        INSERT INTO session_block_exercises (
          id, block_id, exercise_id, exercise_index, prescription,
          setup_duration_seconds, work_duration_seconds, rest_duration_seconds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          blockId,
          exercise.id,
          exerciseIndex,
          exercise.prescription,
          exercise.setupDuration?.inSeconds,
          exercise.workDuration?.inSeconds,
          exercise.restDuration?.inSeconds,
        ],
      );
    }
  }

  Future<void> logSet({
    required Session session,
    required SessionSetLog setLog,
  }) async {
    final String now = DateTime.now().toIso8601String();

    await _powerSync.execute(
      '''
      INSERT INTO session_set_logs (
        id, block_id, exercise_id, set_index,
        weight_kg, reps, duration_seconds, unit_remaining
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        setLog.id,
        setLog.sessionBlockId,
        setLog.exerciseId,
        setLog.setIndex,
        setLog.weightKg,
        setLog.reps,
        setLog.duration?.inSeconds,
        setLog.unitRemaining,
      ],
    );

    await _touchSessionUpdatedAt(session.id, now);
  }

  /// Removes the most recent logged set for an exercise in a block.
  Future<void> unlogSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) async {
    final List<Map<String, dynamic>> latestLogRows = await _powerSync.getAll(
      '''
      SELECT set_index FROM session_set_logs
      WHERE block_id = ? AND exercise_id = ?
      ORDER BY set_index DESC
      LIMIT 1
      ''',
      [block.id, exercise.id],
    );

    if (latestLogRows.isEmpty) return;

    final int latestSetIndex = latestLogRows.first['set_index'] as int;

    await _powerSync.execute(
      '''
      DELETE FROM session_set_logs
      WHERE block_id = ? AND exercise_id = ? AND set_index = ?
      ''',
      [block.id, exercise.id, latestSetIndex],
    );

    await _touchSessionUpdatedAt(
      session.id,
      DateTime.now().toIso8601String(),
    );
  }

  /// Fetches a session by ID, eagerly loading all blocks, exercises, and logs.
  Future<Session> fetchSessionById(String sessionId) async {
    final List<Map<String, dynamic>> sessionRows = await _powerSync.getAll(
      'SELECT * FROM sessions WHERE id = ?',
      [sessionId],
    );

    if (sessionRows.isEmpty) {
      throw Exception('Session not found: $sessionId');
    }

    final Map<String, dynamic> sessionRow = sessionRows.first;

    final List<Map<String, dynamic>> blockRows = await _powerSync.getAll(
      '''
      SELECT * FROM session_blocks
      WHERE session_id = ?
      ORDER BY block_index
      ''',
      [sessionId],
    );

    final List<SessionBlock> blocks = [];
    for (final Map<String, dynamic> blockRow in blockRows) {
      final String blockId = blockRow['id'] as String;

      final List<Map<String, dynamic>> exerciseRows =
          await _powerSync.getAll(
        '''
        SELECT 
          e.id as e_id,
          e.name as e_name,
          e.modality as e_modality,
          e.equipment as e_equipment,
          e.cues as e_cues,
          sbe.prescription as sbe_prescription,
          sbe.setup_duration_seconds as sbe_setup_duration_seconds,
          sbe.work_duration_seconds as sbe_work_duration_seconds,
          sbe.rest_duration_seconds as sbe_rest_duration_seconds
        FROM session_block_exercises sbe
        INNER JOIN exercises e ON e.id = sbe.exercise_id
        WHERE sbe.block_id = ?
        ORDER BY sbe.exercise_index
        ''',
        [blockId],
      );

      final List<WorkoutExercise> exercises = exerciseRows
          .map(
            (exerciseRow) => mappers.sessionExerciseFromJoinRow(exerciseRow),
          )
          .toList();

      final List<Map<String, dynamic>> logRows = await _powerSync.getAll(
        '''
        SELECT * FROM session_set_logs
        WHERE block_id = ?
        ORDER BY set_index
        ''',
        [blockId],
      );

      final List<SessionSetLog> logs = logRows
          .map((logRow) => mappers.sessionSetLogFromRow(logRow))
          .toList();

      blocks.add(mappers.sessionBlockFromRow(blockRow, exercises, logs));
    }

    return mappers.sessionFromRow(sessionRow, blocks);
  }

  Future<List<Session>> fetchSessions() async {
    final List<Map<String, dynamic>> sessionRows = await _powerSync.getAll(
      'SELECT * FROM sessions ORDER BY started_at DESC',
    );

    final List<Session> sessions = [];
    for (final Map<String, dynamic> sessionRow in sessionRows) {
      final String sessionId = sessionRow['id'] as String;
      sessions.add(await fetchSessionById(sessionId));
    }
    return sessions;
  }

  Stream<List<Session>> watchSessions() {
    return _powerSync
        .watch('SELECT * FROM sessions ORDER BY started_at DESC')
        .asyncMap((sessionRows) async {
          final List<Session> sessions = [];
          for (final Map<String, dynamic> sessionRow in sessionRows) {
            final String sessionId = sessionRow['id'] as String;
            sessions.add(await fetchSessionById(sessionId));
          }
          return sessions;
        });
  }

  Stream<List<SessionCalendarDay>> watchSessionCalendarDays() => _powerSync
      .watch(
        '''
        SELECT
          DATE(s.started_at, 'localtime') AS day,
          SUM(s.duration_seconds)           AS total_duration_seconds,
          COALESCE(SUM(m.zone1_seconds), 0) AS total_zone1_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          COALESCE(SUM(m.zone3_seconds), 0) AS total_zone3_seconds,
          COALESCE(SUM(m.zone4_seconds), 0) AS total_zone4_seconds,
          COALESCE(SUM(m.zone5_seconds), 0) AS total_zone5_seconds,
          COALESCE(SUM(m.trimp), 0.0)       AS total_trimp,
          COUNT(s.id)                       AS session_count
        FROM sessions s
        LEFT JOIN session_computed_metrics m ON m.id = s.id
        WHERE s.completed_at IS NOT NULL
        GROUP BY day
        ORDER BY day ASC
        ''',
        triggerOnTables: const {'sessions', 'session_computed_metrics'},
      )
      .map(
        (dayRows) => dayRows.map(_calendarDayFromRow).toList(),
      );

  Future<List<Session>> getSessionsForDate(DateTime localDate) async {
    final String dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> sessionRows = await _powerSync.getAll(
      "SELECT id FROM sessions WHERE completed_at IS NOT NULL"
      " AND DATE(started_at, 'localtime') = ?"
      " ORDER BY started_at ASC",
      [dayString],
    );
    final List<Session> sessions = [];
    for (final Map<String, dynamic> sessionRow in sessionRows) {
      sessions.add(await fetchSessionById(sessionRow['id'] as String));
    }
    return sessions;
  }

  Future<void> completeSession(
    Session session, {
    String? notes,
    String? feeling,
    TrainingLoadCalculator? trainingLoad,
  }) async {
    final String now = DateTime.now().toIso8601String();
    final DateTime completedAt = DateTime.now();

    Duration activeDuration =
        completedAt.difference(session.startedAt);
    if (session.isPaused && session.pausedAt != null) {
      activeDuration -= DateTime.now().difference(session.pausedAt!);
    }
    activeDuration -= session.totalPausedDuration;

    final List<Map<String, dynamic>> heartRateStats = await _powerSync.getAll(
      '''
      SELECT AVG(bpm) as avg_bpm, MAX(bpm) as max_bpm
      FROM heart_rate_samples
      WHERE session_id = ?
      ''',
      [session.id],
    );
    final num? avgBpm = heartRateStats.first['avg_bpm'] as num?;
    final int? maxBpm = heartRateStats.first['max_bpm'] as int?;

    await _powerSync.execute(
      '''
      UPDATE sessions
      SET completed_at = ?, duration_seconds = ?, notes = ?, paused_at = NULL,
          average_heart_rate = ?, max_heart_rate = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        completedAt.toIso8601String(),
        activeDuration.inSeconds,
        notes ?? '',
        avgBpm?.round(),
        maxBpm,
        now,
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
    await _powerSync.execute(
      'DELETE FROM sessions WHERE id = ?',
      [sessionId],
    );
    _log.info('Deleted session $sessionId (queued for upload).');
  }

  Future<void> discardAllInProgressSessions() async {
    await _powerSync.execute(
      'DELETE FROM sessions WHERE completed_at IS NULL',
    );
  }

  /// Returns all sessions sorted with in-progress first, then by most recent.
  Future<List<Session>> history() async {
    final List<Session> sessions = await fetchSessions();

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
    final String now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      'UPDATE sessions SET paused_at = ?, updated_at = ? WHERE id = ?',
      [now, now, session.id],
    );
  }

  Future<void> resumeSession(Session session) async {
    final String now = DateTime.now().toIso8601String();
    if (session.pausedAt == null) return;

    final Duration pauseDuration =
        DateTime.now().difference(session.pausedAt!);
    final Duration totalPausedDuration =
        session.totalPausedDuration + pauseDuration;

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
  ) async {
    final SessionBlock targetBlock =
        session.blocks.firstWhere((block) => block.id == blockId);
    final Set<String> siblingBlockIds =
        _findSiblingBlockIds(session, targetBlock);

    final List<Map<String, dynamic>> indexRows = await _powerSync.getAll(
      '''
      SELECT exercise_index FROM session_block_exercises
      WHERE block_id = ?
      ORDER BY exercise_index DESC
      LIMIT 1
      ''',
      [blockId],
    );

    final int nextExerciseIndex = indexRows.isEmpty
        ? 0
        : (indexRows.first['exercise_index'] as int) + 1;

    for (final String siblingBlockId in siblingBlockIds) {
      await _powerSync.execute(
        '''
        INSERT INTO session_block_exercises (
          id, block_id, exercise_id, exercise_index, prescription,
          setup_duration_seconds, work_duration_seconds, rest_duration_seconds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          siblingBlockId,
          exercise.id,
          nextExerciseIndex,
          exercise.prescription,
          exercise.setupDuration?.inSeconds,
          exercise.workDuration?.inSeconds,
          exercise.restDuration?.inSeconds,
        ],
      );
    }

    await _touchSessionUpdatedAt(
      session.id,
      DateTime.now().toIso8601String(),
    );
    return fetchSessionById(session.id);
  }

  Future<Session> removeExercise(
    Session session,
    String blockId,
    String exerciseId,
  ) async {
    final SessionBlock targetBlock =
        session.blocks.firstWhere((block) => block.id == blockId);
    final Set<String> siblingBlockIds =
        _findSiblingBlockIds(session, targetBlock);

    for (final String siblingBlockId in siblingBlockIds) {
      await _powerSync.execute(
        'DELETE FROM session_set_logs WHERE block_id = ? AND exercise_id = ?',
        [siblingBlockId, exerciseId],
      );
      await _powerSync.execute(
        'DELETE FROM session_block_exercises'
        ' WHERE block_id = ? AND exercise_id = ?',
        [siblingBlockId, exerciseId],
      );
    }

    await _touchSessionUpdatedAt(
      session.id,
      DateTime.now().toIso8601String(),
    );
    return fetchSessionById(session.id);
  }

  /// Recomputes zones for all completed sessions (triggered by max HR change).
  /// Preserves existing TRIMP values computed with their original resting HR.
  Future<void> recomputeZones({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) => _metricsStore.recomputeAllZones(
    trainingLoad: trainingLoad,
    onProgress: onProgress,
  );

  /// Backfills metrics for completed sessions missing a
  /// `session_computed_metrics` row.
  Future<void> backfillMissingMetrics({
    required TrainingLoadCalculator trainingLoad,
  }) => _metricsStore.backfillMissing(trainingLoad: trainingLoad);

  /// Returns sibling block IDs — blocks that share the same round structure,
  /// so that exercises added to one round propagate to all rounds.
  Set<String> _findSiblingBlockIds(Session session, SessionBlock target) {
    if (target.totalRounds == null) return {target.id};
    return session.blocks
        .where(
          (block) =>
              block.type == target.type &&
              block.totalRounds == target.totalRounds,
        )
        .map((block) => block.id)
        .toSet();
  }

  Future<void> _touchSessionUpdatedAt(String sessionId, String now) =>
      _powerSync.execute(
        'UPDATE sessions SET updated_at = ? WHERE id = ?',
        [now, sessionId],
      );

  SessionCalendarDay _calendarDayFromRow(Map<String, dynamic> dayRow) {
    final String dayString = dayRow['day'] as String;
    final List<String> parts = dayString.split('-');
    final zoneMinutes = _zoneMinutesFromRow(dayRow);
    return SessionCalendarDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      totalDurationSeconds: (dayRow['total_duration_seconds'] as int?) ?? 0,
      zone1Minutes: zoneMinutes[0],
      zone2Minutes: zoneMinutes[1],
      zone3Minutes: zoneMinutes[2],
      zone4Minutes: zoneMinutes[3],
      zone5Minutes: zoneMinutes[4],
      trimp: (dayRow['total_trimp'] as num?)?.toDouble() ?? 0,
      sessionCount: (dayRow['session_count'] as int?) ?? 0,
    );
  }

  List<int> _zoneMinutesFromRow(Map<String, dynamic> row) => [
        for (var z = 1; z <= 5; z++)
          ((row['total_zone${z}_seconds'] as int? ?? 0) ~/ 60),
      ];
}

@riverpod
SessionRepositoryPowerSync sessionRepositoryPowerSync(Ref ref) {
  final PowerSyncDatabase? powerSync =
      ref.watch(powerSyncDatabaseProvider).value;
  if (powerSync == null) {
    throw StateError('PowerSync database not initialized');
  }
  final TemplateRepositoryPowerSync templateRepo =
      ref.watch(templateRepositoryPowerSyncProvider);
  return SessionRepositoryPowerSync(powerSync, templateRepo);
}
