import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/repositories/session/session_hydrator.dart';
import 'package:workouts/services/repositories/session/session_set_log_store.dart';

const _uuid = Uuid();

class SessionExerciseStore {
  SessionExerciseStore(
    this._powerSync,
    this._sessionHydrator,
    this._setLogStore,
  );

  final PowerSyncDatabase _powerSync;
  final SessionHydrator _sessionHydrator;
  final SessionSetLogStore _setLogStore;

  Future<Session> addExercise(
    Session session,
    String blockId,
    WorkoutExercise exercise,
  ) async {
    final targetBlock = session.blocks.firstWhere(
      (block) => block.id == blockId,
    );
    final siblingBlockIds = _findSiblingBlockIds(session, targetBlock);

    final indexRows = await _powerSync.getAll(
      '''
      SELECT exercise_index FROM session_block_exercises
      WHERE block_id = ?
      ORDER BY exercise_index DESC
      LIMIT 1
      ''',
      [blockId],
    );

    final nextExerciseIndex = indexRows.isEmpty
        ? 0
        : (indexRows.first['exercise_index'] as int) + 1;

    for (final siblingBlockId in siblingBlockIds) {
      await _powerSync.execute(
        '''
        INSERT INTO session_block_exercises (
          id, block_id, exercise_id, exercise_index, prescription, planned_sets,
          setup_duration_seconds, work_duration_seconds, rest_duration_seconds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          siblingBlockId,
          exercise.id,
          nextExerciseIndex,
          exercise.prescription,
          PlannedSet.listToJsonString(exercise.plannedSets),
          exercise.setupDuration?.inSeconds,
          exercise.workDuration?.inSeconds,
          exercise.restDuration?.inSeconds,
        ],
      );
    }

    await _setLogStore.touchSessionUpdatedAt(
      session.id,
      DateTime.now().toUtc().toIso8601String(),
    );
    return _sessionHydrator.fetchSessionById(session.id);
  }

  Future<Session> removeExercise(
    Session session,
    String blockId,
    String exerciseId,
  ) async {
    final targetBlock = session.blocks.firstWhere(
      (block) => block.id == blockId,
    );
    final siblingBlockIds = _findSiblingBlockIds(session, targetBlock);

    for (final siblingBlockId in siblingBlockIds) {
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

    await _setLogStore.touchSessionUpdatedAt(
      session.id,
      DateTime.now().toUtc().toIso8601String(),
    );
    return _sessionHydrator.fetchSessionById(session.id);
  }

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
}
