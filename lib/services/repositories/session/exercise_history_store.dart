import 'package:powersync/powersync.dart';
import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/powersync/powersync_mappers.dart' as mappers;

/// Cross-session query: "the last N times this exercise was logged".
///
/// Kept separate from `SessionHydrator` (which hydrates whole sessions) to
/// avoid coupling: the inputs are different (exercise id vs session id),
/// the output shape is different (slim entries vs full aggregates), and
/// hydrating full sessions just to filter their logs would be wasteful.
class ExerciseHistoryStore {
  ExerciseHistoryStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  /// Returns the most recent completed sessions in which [exerciseId] was
  /// logged, newest first, capped at [limit]. Each entry carries only the
  /// matching set logs and a small amount of session metadata; the caller
  /// fetches the full Session on demand if the user drills in.
  ///
  /// In-progress (not-yet-completed) sessions are excluded — they would
  /// otherwise include the active session's logs and confuse the "last
  /// time I did this" reading.
  Future<List<ExerciseHistoryEntry>> fetch({
    required String exerciseId,
    int limit = 10,
  }) async {
    final sessionRows = await _powerSync.getAll(
      '''
      SELECT DISTINCT s.id AS session_id,
                      s.completed_at AS completed_at,
                      wt.name AS template_name
      FROM sessions s
      LEFT JOIN workout_templates wt ON wt.id = s.template_id
      JOIN session_blocks sb ON sb.session_id = s.id
      JOIN session_set_logs ssl ON ssl.block_id = sb.id
      WHERE ssl.exercise_id = ?
        AND s.completed_at IS NOT NULL
      ORDER BY s.completed_at DESC
      LIMIT ?
      ''',
      [exerciseId, limit],
    );
    if (sessionRows.isEmpty) return const [];

    final logsBySessionId = await _fetchLogsForSessions(
      exerciseId: exerciseId,
      sessionIds: sessionRows
          .map((row) => row['session_id'] as String)
          .toList(),
    );

    return sessionRows
        .map(
          (row) => _entryFromRow(row, logsBySessionId),
        )
        .toList();
  }

  Future<Map<String, List<SessionSetLog>>> _fetchLogsForSessions({
    required String exerciseId,
    required List<String> sessionIds,
  }) async {
    final placeholders = List.filled(sessionIds.length, '?').join(', ');
    final logRows = await _powerSync.getAll(
      '''
      SELECT ssl.*, sb.session_id AS log_session_id, sb.block_index
      FROM session_set_logs ssl
      JOIN session_blocks sb ON sb.id = ssl.block_id
      WHERE ssl.exercise_id = ? AND sb.session_id IN ($placeholders)
      ORDER BY sb.block_index ASC, ssl.set_index ASC
      ''',
      [exerciseId, ...sessionIds],
    );

    final logsBySessionId = <String, List<SessionSetLog>>{};
    for (final logRow in logRows) {
      final sessionId = logRow['log_session_id'] as String;
      logsBySessionId
          .putIfAbsent(sessionId, () => [])
          .add(mappers.sessionSetLogFromRow(logRow));
    }
    return logsBySessionId;
  }

  ExerciseHistoryEntry _entryFromRow(
    Map<String, dynamic> sessionRow,
    Map<String, List<SessionSetLog>> logsBySessionId,
  ) {
    final sessionId = sessionRow['session_id'] as String;
    return ExerciseHistoryEntry(
      sessionId: sessionId,
      completedAt: DateTime.parse(sessionRow['completed_at'] as String)
          .toLocal(),
      templateName: sessionRow['template_name'] as String?,
      sets: logsBySessionId[sessionId] ?? const [],
    );
  }
}
