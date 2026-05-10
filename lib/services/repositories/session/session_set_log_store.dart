import 'package:powersync/powersync.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

class SessionSetLogStore {
  SessionSetLogStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> logSet({
    required Session session,
    required SessionSetLog setLog,
  }) async {
    final now = DateTime.now().toIso8601String();

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

    await touchSessionUpdatedAt(session.id, now);
  }

  Future<void> unlogSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) async {
    final latestLogRows = await _powerSync.getAll(
      '''
      SELECT set_index FROM session_set_logs
      WHERE block_id = ? AND exercise_id = ?
      ORDER BY set_index DESC
      LIMIT 1
      ''',
      [block.id, exercise.id],
    );

    if (latestLogRows.isEmpty) return;

    final latestSetIndex = latestLogRows.first['set_index'] as int;

    await _powerSync.execute(
      '''
      DELETE FROM session_set_logs
      WHERE block_id = ? AND exercise_id = ? AND set_index = ?
      ''',
      [block.id, exercise.id, latestSetIndex],
    );

    await touchSessionUpdatedAt(session.id, DateTime.now().toIso8601String());
  }

  Future<void> touchSessionUpdatedAt(String sessionId, String now) =>
      _powerSync.execute('UPDATE sessions SET updated_at = ? WHERE id = ?', [
        now,
        sessionId,
      ]);
}
