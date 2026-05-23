import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/repositories/library_exercise_store.dart';
import 'package:workouts/services/repositories/session/session_hydrator.dart';
import 'package:workouts/services/repositories/session/session_set_log_store.dart';

const _uuid = Uuid();

class SessionExerciseStore {
  SessionExerciseStore(
    this._powerSync,
    this._sessionHydrator,
    this._setLogStore,
  ) : _libraryExerciseStore = LibraryExerciseStore(_powerSync);

  final PowerSyncDatabase _powerSync;
  final SessionHydrator _sessionHydrator;
  final SessionSetLogStore _setLogStore;
  final LibraryExerciseStore _libraryExerciseStore;

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

  /// Replaces [oldExerciseId] with [newExercise] in the target block and all
  /// sibling round blocks. Discards any logged sets attributed to the old
  /// exercise (the new movement is different — preserving its sets would
  /// misattribute work). If [newExercise] is not yet in the library, it is
  /// upserted first.
  Future<Session> replaceExercise(
    Session session,
    String blockId,
    String oldExerciseId,
    WorkoutExercise newExercise,
  ) async {
    final canonicalNewExerciseId = await _libraryExerciseStore.upsert(
      newExercise,
    );

    final targetBlock = session.blocks.firstWhere(
      (block) => block.id == blockId,
    );
    final siblingBlockIds = _findSiblingBlockIds(session, targetBlock);

    for (final siblingBlockId in siblingBlockIds) {
      await _powerSync.execute(
        'DELETE FROM session_set_logs WHERE block_id = ? AND exercise_id = ?',
        [siblingBlockId, oldExerciseId],
      );
      await _powerSync.execute(
        '''
        UPDATE session_block_exercises
        SET exercise_id = ?
        WHERE block_id = ? AND exercise_id = ?
        ''',
        [canonicalNewExerciseId, siblingBlockId, oldExerciseId],
      );
    }

    await _setLogStore.touchSessionUpdatedAt(
      session.id,
      DateTime.now().toUtc().toIso8601String(),
    );
    return _sessionHydrator.fetchSessionById(session.id);
  }

  /// Overwrites the planned-set list for one exercise within one block.
  /// Single block only — warmup adjustments are per-block, not propagated
  /// across sibling rounds (each round's warmup count is independent).
  Future<void> updatePlannedSets({
    required String sessionId,
    required String sessionBlockId,
    required String exerciseId,
    required List<PlannedSet> plannedSets,
  }) async {
    await _powerSync.execute(
      '''
      UPDATE session_block_exercises
      SET planned_sets = ?
      WHERE block_id = ? AND exercise_id = ?
      ''',
      [PlannedSet.listToJsonString(plannedSets), sessionBlockId, exerciseId],
    );
    await _setLogStore.touchSessionUpdatedAt(
      sessionId,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Rewrites `exercise_index` for every exercise in [orderedExerciseIds]
  /// across the target block and all sibling round blocks, so all rounds
  /// stay in lock-step with the new ordering.
  ///
  /// The unique constraint `(block_id, exercise_id, exercise_index)` cannot
  /// collide during shuffling because `exercise_id` is already unique per
  /// block — so a single-pass UPDATE per row is safe.
  Future<Session> reorderExercises(
    Session session,
    String blockId,
    List<String> orderedExerciseIds,
  ) async {
    final targetBlock = session.blocks.firstWhere(
      (block) => block.id == blockId,
    );
    final siblingBlockIds = _findSiblingBlockIds(session, targetBlock);

    for (final siblingBlockId in siblingBlockIds) {
      for (var newIndex = 0; newIndex < orderedExerciseIds.length; newIndex++) {
        await _powerSync.execute(
          '''
          UPDATE session_block_exercises
          SET exercise_index = ?
          WHERE block_id = ? AND exercise_id = ?
          ''',
          [newIndex, siblingBlockId, orderedExerciseIds[newIndex]],
        );
      }
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
