import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_rounds.dart';
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
    final newIndex = await _nextExerciseIndexIn(blockId);
    await _propagateAcrossRoundsOf(
      session,
      blockId,
      (roundBlockId) => _insertExerciseRow(
        blockId: roundBlockId,
        exercise: exercise,
        index: newIndex,
      ),
    );
    return _finalizeMutation(session.id);
  }

  Future<Session> removeExercise(
    Session session,
    String blockId,
    String exerciseId,
  ) async {
    await _propagateAcrossRoundsOf(session, blockId, (roundBlockId) async {
      await _deleteSetLogsFor(blockId: roundBlockId, exerciseId: exerciseId);
      await _deleteExerciseRow(blockId: roundBlockId, exerciseId: exerciseId);
    });
    return _finalizeMutation(session.id);
  }

  /// Replaces [oldExerciseId] with [newExercise] in every round of the
  /// target block. Discards any logged sets attributed to the old exercise
  /// (the new movement is different — preserving its sets would misattribute
  /// work). If [newExercise] is not yet in the library, it is upserted
  /// first.
  Future<Session> replaceExercise(
    Session session,
    String blockId,
    String oldExerciseId,
    WorkoutExercise newExercise,
  ) async {
    final canonicalNewExerciseId = await _libraryExerciseStore.upsert(
      newExercise,
    );
    await _propagateAcrossRoundsOf(session, blockId, (roundBlockId) async {
      await _deleteSetLogsFor(
        blockId: roundBlockId,
        exerciseId: oldExerciseId,
      );
      await _swapExerciseId(
        blockId: roundBlockId,
        oldExerciseId: oldExerciseId,
        newExerciseId: canonicalNewExerciseId,
      );
    });
    return _finalizeMutation(session.id);
  }

  /// Overwrites the planned-set list for one exercise within one block.
  /// Single block only — warmup adjustments are per-block, not propagated
  /// across other rounds (each round's warmup count is independent).
  Future<void> updatePlannedSets({
    required String sessionId,
    required String sessionBlockId,
    required String exerciseId,
    required List<PlannedSet> plannedSets,
  }) async {
    await _writePlannedSets(
      blockId: sessionBlockId,
      exerciseId: exerciseId,
      plannedSets: plannedSets,
    );
    await _markSessionDirty(sessionId);
  }

  /// Rewrites `exercise_index` for every exercise in [orderedExerciseIds]
  /// across every round of the target block, so all rounds stay in
  /// lock-step with the new ordering.
  ///
  /// The unique constraint `(block_id, exercise_id, exercise_index)` cannot
  /// collide during shuffling because `exercise_id` is already unique per
  /// block — so a single-pass UPDATE per row is safe.
  Future<Session> reorderExercises(
    Session session,
    String blockId,
    List<String> orderedExerciseIds,
  ) async {
    await _propagateAcrossRoundsOf(
      session,
      blockId,
      (roundBlockId) => _writeExerciseOrder(
        blockId: roundBlockId,
        orderedExerciseIds: orderedExerciseIds,
      ),
    );
    return _finalizeMutation(session.id);
  }

  /// Runs [work] for every round of [blockId] in declared order. The
  /// multi-round propagation rule lives here exactly once: every public
  /// mutation method that needs to apply across rounds calls this with its
  /// per-round work as a closure.
  Future<void> _propagateAcrossRoundsOf(
    Session session,
    String blockId,
    Future<void> Function(String roundBlockId) work,
  ) async {
    for (final roundBlockId in session.allRoundsOfBlock(blockId)) {
      await work(roundBlockId);
    }
  }

  Future<int> _nextExerciseIndexIn(String blockId) async {
    final rows = await _powerSync.getAll(
      '''
      SELECT exercise_index FROM session_block_exercises
      WHERE block_id = ?
      ORDER BY exercise_index DESC
      LIMIT 1
      ''',
      [blockId],
    );
    return rows.isEmpty ? 0 : (rows.first['exercise_index'] as int) + 1;
  }

  Future<void> _insertExerciseRow({
    required String blockId,
    required WorkoutExercise exercise,
    required int index,
  }) => _powerSync.execute(
    '''
    INSERT INTO session_block_exercises (
      id, block_id, exercise_id, exercise_index, prescription, planned_sets,
      setup_duration_seconds, work_duration_seconds, rest_duration_seconds
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      _uuid.v4(),
      blockId,
      exercise.id,
      index,
      exercise.prescription,
      PlannedSet.listToJsonString(exercise.plannedSets),
      exercise.setupDuration?.inSeconds,
      exercise.workDuration?.inSeconds,
      exercise.restDuration?.inSeconds,
    ],
  );

  Future<void> _deleteExerciseRow({
    required String blockId,
    required String exerciseId,
  }) => _powerSync.execute(
    'DELETE FROM session_block_exercises'
    ' WHERE block_id = ? AND exercise_id = ?',
    [blockId, exerciseId],
  );

  Future<void> _deleteSetLogsFor({
    required String blockId,
    required String exerciseId,
  }) => _powerSync.execute(
    'DELETE FROM session_set_logs WHERE block_id = ? AND exercise_id = ?',
    [blockId, exerciseId],
  );

  Future<void> _swapExerciseId({
    required String blockId,
    required String oldExerciseId,
    required String newExerciseId,
  }) => _powerSync.execute(
    '''
    UPDATE session_block_exercises
    SET exercise_id = ?
    WHERE block_id = ? AND exercise_id = ?
    ''',
    [newExerciseId, blockId, oldExerciseId],
  );

  Future<void> _writePlannedSets({
    required String blockId,
    required String exerciseId,
    required List<PlannedSet> plannedSets,
  }) => _powerSync.execute(
    '''
    UPDATE session_block_exercises
    SET planned_sets = ?
    WHERE block_id = ? AND exercise_id = ?
    ''',
    [PlannedSet.listToJsonString(plannedSets), blockId, exerciseId],
  );

  Future<void> _writeExerciseOrder({
    required String blockId,
    required List<String> orderedExerciseIds,
  }) async {
    for (var newIndex = 0; newIndex < orderedExerciseIds.length; newIndex++) {
      await _powerSync.execute(
        '''
        UPDATE session_block_exercises
        SET exercise_index = ?
        WHERE block_id = ? AND exercise_id = ?
        ''',
        [newIndex, blockId, orderedExerciseIds[newIndex]],
      );
    }
  }

  /// Marks the session row dirty so PowerSync uploads it, then re-hydrates
  /// the session so the caller sees the post-mutation state.
  Future<Session> _finalizeMutation(String sessionId) async {
    await _markSessionDirty(sessionId);
    return _sessionHydrator.fetchSessionById(sessionId);
  }

  Future<void> _markSessionDirty(String sessionId) =>
      _setLogStore.touchSessionUpdatedAt(
        sessionId,
        DateTime.now().toUtc().toIso8601String(),
      );
}
