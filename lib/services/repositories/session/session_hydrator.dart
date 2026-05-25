import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_calendar_day.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/powersync/powersync_mappers.dart' as mappers;

class SessionHydrator {
  SessionHydrator(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<Session> fetchSessionById(String sessionId) async {
    final sessionRows = await _powerSync.getAll(
      'SELECT * FROM sessions WHERE id = ?',
      [sessionId],
    );

    if (sessionRows.isEmpty) {
      throw Exception('Session not found: $sessionId');
    }

    final sessionRow = sessionRows.first;
    final blockRows = await _powerSync.getAll(
      '''
      SELECT * FROM session_blocks
      WHERE session_id = ?
      ORDER BY block_index
      ''',
      [sessionId],
    );

    final blocks = <SessionBlock>[];
    for (final blockRow in blockRows) {
      final blockId = blockRow['id'] as String;
      final exercises = await _hydrateExercises(blockId);
      final logs = await _hydrateLogs(blockId);
      blocks.add(mappers.sessionBlockFromRow(blockRow, exercises, logs));
    }

    return mappers.sessionFromRow(sessionRow, blocks);
  }

  Future<List<WorkoutExercise>> _hydrateExercises(String blockId) async {
    final exerciseRows = await _powerSync.getAll(
      '''
      SELECT 
        e.id as e_id,
        e.name as e_name,
        e.modality as e_modality,
        e.equipment as e_equipment,
        e.set_metrics_style as e_set_metrics_style,
        e.cues as e_cues,
        e.benefits as e_benefits,
        e.is_unilateral as e_is_unilateral,
        sbe.prescription as sbe_prescription,
        sbe.planned_sets as sbe_planned_sets,
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

    return exerciseRows
        .map((exerciseRow) => mappers.sessionExerciseFromJoinRow(exerciseRow))
        .toList();
  }

  Future<List<SessionSetLog>> _hydrateLogs(String blockId) async {
    final logRows = await _powerSync.getAll(
      '''
      SELECT * FROM session_set_logs
      WHERE block_id = ?
      ORDER BY set_index
      ''',
      [blockId],
    );

    return logRows
        .map((logRow) => mappers.sessionSetLogFromRow(logRow))
        .toList();
  }

  Future<List<Session>> fetchSessions() async {
    final sessionRows = await _powerSync.getAll(
      'SELECT * FROM sessions ORDER BY started_at DESC',
    );

    final sessions = <Session>[];
    for (final sessionRow in sessionRows) {
      sessions.add(await fetchSessionById(sessionRow['id'] as String));
    }
    return sessions;
  }

  Stream<List<Session>> watchSessions() {
    return _powerSync
        .watch('SELECT * FROM sessions ORDER BY started_at DESC')
        .asyncMap((sessionRows) async {
          final sessions = <Session>[];
          for (final sessionRow in sessionRows) {
            sessions.add(await fetchSessionById(sessionRow['id'] as String));
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
          COUNT(s.id)                       AS session_count
        FROM sessions s
        LEFT JOIN session_computed_metrics m ON m.id = s.id
        WHERE s.completed_at IS NOT NULL
        GROUP BY day
        ORDER BY day ASC
        ''',
        triggerOnTables: const {'sessions', 'session_computed_metrics'},
      )
      .map((dayRows) => dayRows.mapL(SessionCalendarDay.fromRow));

  Future<List<Session>> getSessionsForDate(DateTime localDate) async {
    final dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final sessionRows = await _powerSync.getAll(
      "SELECT id FROM sessions WHERE completed_at IS NOT NULL"
      " AND DATE(started_at, 'localtime') = ?"
      " ORDER BY started_at ASC",
      [dayString],
    );
    final sessions = <Session>[];
    for (final sessionRow in sessionRows) {
      sessions.add(await fetchSessionById(sessionRow['id'] as String));
    }
    return sessions;
  }
}
