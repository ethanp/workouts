import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/powersync_database_provider.dart';
import 'package:workouts/services/powersync_mappers.dart' as mappers;
import 'package:workouts/services/repositories/template_repository_powersync.dart';

part 'session_repository_powersync.g.dart';

const _uuid = Uuid();

class SessionRepositoryPowerSync {
  SessionRepositoryPowerSync(this._db, this._templateRepository);

  final PowerSyncDatabase _db;
  final TemplateRepositoryPowerSync _templateRepository;

  /// Start a new session from a template.
  Future<Session> startSession(String templateId) async {
    final templates = await _templateRepository.fetchTemplates();
    final template = templates.firstWhere((item) => item.id == templateId);

    final sessionId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    // Insert session
    await _db.execute(
      '''
      INSERT INTO sessions (
        id, template_id, started_at, paused_at, total_paused_duration_seconds, updated_at
      ) VALUES (?, ?, ?, NULL, 0, ?)
      ''',
      [sessionId, templateId, now, now],
    );

    final sessionBlocks = <SessionBlock>[];
    var blockIndex = 0;

    // Create session blocks from template blocks
    for (final templateBlock in template.blocks) {
      final totalRounds = templateBlock.rounds <= 0 ? 1 : templateBlock.rounds;
      final hasMultipleRounds = totalRounds > 1;

      for (var round = 0; round < totalRounds; round++) {
        final blockId = _uuid.v4();

        // Insert session block
        await _db.execute(
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
            hasMultipleRounds ? round + 1 : null,
            hasMultipleRounds ? totalRounds : null,
          ],
        );

        // Insert session block exercises from template block exercises
        for (
          var exerciseIndex = 0;
          exerciseIndex < templateBlock.exercises.length;
          exerciseIndex++
        ) {
          final exercise = templateBlock.exercises[exerciseIndex];

          await _db.execute(
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

        // Build SessionBlock model
        sessionBlocks.add(
          SessionBlock(
            id: blockId,
            sessionId: sessionId,
            type: templateBlock.type,
            blockIndex: blockIndex,
            exercises: templateBlock.exercises,
            logs: const [],
            targetDuration: templateBlock.targetDuration,
            roundIndex: hasMultipleRounds ? round + 1 : null,
            totalRounds: hasMultipleRounds ? totalRounds : null,
          ),
        );

        blockIndex++;
      }
    }

    return Session(
      id: sessionId,
      templateId: templateId,
      startedAt: DateTime.now(),
      blocks: sessionBlocks,
    );
  }

  /// Log a completed set.
  Future<void> logSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
    required SessionSetLog log,
  }) async {
    final now = DateTime.now().toIso8601String();

    // Insert set log
    await _db.execute(
      '''
      INSERT INTO session_set_logs (
        id, block_id, exercise_id, set_index,
        weight_kg, reps, duration_seconds, unit_remaining
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        log.id,
        log.sessionBlockId,
        log.exerciseId,
        log.setIndex,
        log.weightKg,
        log.reps,
        log.duration?.inSeconds,
        log.unitRemaining,
      ],
    );

    // Update session updated_at
    await _db.execute('UPDATE sessions SET updated_at = ? WHERE id = ?', [
      now,
      session.id,
    ]);
  }

  /// Remove the last logged set for an exercise in a block.
  Future<void> unlogSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) async {
    // Find the highest set_index for this block/exercise
    final logRows = await _db.getAll(
      '''
      SELECT set_index FROM session_set_logs
      WHERE block_id = ? AND exercise_id = ?
      ORDER BY set_index DESC
      LIMIT 1
      ''',
      [block.id, exercise.id],
    );

    if (logRows.isEmpty) return;

    final setIndex = logRows.first['set_index'] as int;

    // Delete the log
    await _db.execute(
      '''
      DELETE FROM session_set_logs
      WHERE block_id = ? AND exercise_id = ? AND set_index = ?
      ''',
      [block.id, exercise.id, setIndex],
    );

    // Update session updated_at
    await _db.execute('UPDATE sessions SET updated_at = ? WHERE id = ?', [
      DateTime.now().toIso8601String(),
      session.id,
    ]);
  }

  /// Fetch a session by ID with all related data.
  Future<Session> fetchSessionById(String sessionId) async {
    // Fetch session
    final sessionRows = await _db.getAll(
      'SELECT * FROM sessions WHERE id = ?',
      [sessionId],
    );

    if (sessionRows.isEmpty) {
      throw Exception('Session not found: $sessionId');
    }

    final sessionRow = sessionRows.first;

    // Fetch blocks
    final blockRows = await _db.getAll(
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

      // Fetch exercises for this block
      final exerciseRows = await _db.getAll(
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

      final exercises = exerciseRows
          .map((row) => mappers.sessionExerciseFromJoinRow(row))
          .toList();

      // Fetch logs for this block
      final logRows = await _db.getAll(
        '''
        SELECT * FROM session_set_logs
        WHERE block_id = ?
        ORDER BY set_index
        ''',
        [blockId],
      );

      final logs = logRows
          .map((row) => mappers.sessionSetLogFromRow(row))
          .toList();

      blocks.add(mappers.sessionBlockFromRow(blockRow, exercises, logs));
    }

    return mappers.sessionFromRow(sessionRow, blocks);
  }

  /// Fetch all sessions, ordered by started_at DESC.
  Future<List<Session>> fetchSessions() async {
    final sessionRows = await _db.getAll(
      'SELECT * FROM sessions ORDER BY started_at DESC',
    );

    final sessions = <Session>[];

    for (final sessionRow in sessionRows) {
      final sessionId = sessionRow['id'] as String;
      sessions.add(await fetchSessionById(sessionId));
    }

    return sessions;
  }

  /// Watch all sessions (reactive stream).
  Stream<List<Session>> watchSessions() {
    return _db
        .watch('SELECT * FROM sessions ORDER BY started_at DESC')
        .asyncMap((sessionRows) async {
          final sessions = <Session>[];
          for (final sessionRow in sessionRows) {
            final sessionId = sessionRow['id'] as String;
            sessions.add(await fetchSessionById(sessionId));
          }
          return sessions;
        });
  }

  /// Complete a session.
  Future<void> completeSession(
    Session session, {
    String? notes,
    String? feeling,
  }) async {
    final now = DateTime.now().toIso8601String();
    final completedAt = DateTime.now();

    // Calculate duration (subtract paused time if needed)
    var duration = completedAt.difference(session.startedAt);
    if (session.isPaused && session.pausedAt != null) {
      duration -= DateTime.now().difference(session.pausedAt!);
    }
    duration -= session.totalPausedDuration;

    await _db.execute(
      '''
      UPDATE sessions
      SET completed_at = ?, duration_seconds = ?, notes = ?, paused_at = NULL, updated_at = ?
      WHERE id = ?
      ''',
      [
        completedAt.toIso8601String(),
        duration.inSeconds,
        notes ?? '',
        now,
        session.id,
      ],
    );
  }

  /// Discard (delete) a session.
  Future<void> discardSession(String sessionId) async {
    // Cascade delete will handle blocks, exercises, and logs
    await _db.execute('DELETE FROM sessions WHERE id = ?', [sessionId]);
  }

  /// Discard all in-progress sessions.
  Future<void> discardAllInProgressSessions() async {
    await _db.execute('DELETE FROM sessions WHERE completed_at IS NULL');
  }

  /// Fetch session history (all sessions, sorted with in-progress first).
  Future<List<Session>> history() async {
    final sessions = await fetchSessions();

    // Sort with in-progress sessions first, then by most recent
    sessions.sort((a, b) {
      // In-progress sessions (no completedAt) come first
      if (a.completedAt == null && b.completedAt != null) return -1;
      if (a.completedAt != null && b.completedAt == null) return 1;

      // Within same status, sort by most recent first
      if (a.completedAt == null && b.completedAt == null) {
        return b.startedAt.compareTo(a.startedAt);
      } else {
        return b.completedAt!.compareTo(a.completedAt!);
      }
    });

    return sessions;
  }

  /// Pause a session.
  Future<void> pauseSession(Session session) async {
    final now = DateTime.now().toIso8601String();

    await _db.execute(
      'UPDATE sessions SET paused_at = ?, updated_at = ? WHERE id = ?',
      [now, now, session.id],
    );
  }

  /// Resume a session.
  Future<void> resumeSession(Session session) async {
    final now = DateTime.now().toIso8601String();

    // Calculate total paused duration
    final pausedAtStr = session.pausedAt?.toIso8601String();
    if (pausedAtStr == null) return;

    final pausedAt = DateTime.parse(pausedAtStr);
    final pauseDuration = DateTime.now().difference(pausedAt);
    final totalPausedDuration = session.totalPausedDuration + pauseDuration;

    await _db.execute(
      '''
      UPDATE sessions
      SET paused_at = NULL, total_paused_duration_seconds = ?, updated_at = ?
      WHERE id = ?
      ''',
      [totalPausedDuration.inSeconds, now, session.id],
    );
  }

  /// Add an exercise to a session block.
  Future<Session> addExercise(
    Session session,
    String blockId,
    WorkoutExercise exercise,
  ) async {
    // Find the target block
    final targetBlock = session.blocks.firstWhere((b) => b.id == blockId);
    final siblingIds = _findSiblingBlockIds(session, targetBlock);

    // Find max exercise_index for this block
    final exerciseRows = await _db.getAll(
      '''
      SELECT exercise_index FROM session_block_exercises
      WHERE block_id = ?
      ORDER BY exercise_index DESC
      LIMIT 1
      ''',
      [blockId],
    );

    final nextIndex = exerciseRows.isEmpty
        ? 0
        : (exerciseRows.first['exercise_index'] as int) + 1;

    // Insert exercise into all sibling blocks
    for (final siblingId in siblingIds) {
      await _db.execute(
        '''
        INSERT INTO session_block_exercises (
          id, block_id, exercise_id, exercise_index, prescription,
          setup_duration_seconds, work_duration_seconds, rest_duration_seconds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          siblingId,
          exercise.id,
          nextIndex,
          exercise.prescription,
          exercise.setupDuration?.inSeconds,
          exercise.workDuration?.inSeconds,
          exercise.restDuration?.inSeconds,
        ],
      );
    }

    // Update session updated_at
    await _db.execute('UPDATE sessions SET updated_at = ? WHERE id = ?', [
      DateTime.now().toIso8601String(),
      session.id,
    ]);

    return fetchSessionById(session.id);
  }

  /// Remove an exercise from a session block.
  Future<Session> removeExercise(
    Session session,
    String blockId,
    String exerciseId,
  ) async {
    final targetBlock = session.blocks.firstWhere((b) => b.id == blockId);
    final siblingIds = _findSiblingBlockIds(session, targetBlock);

    // Delete exercise from all sibling blocks
    for (final siblingId in siblingIds) {
      // Delete logs first (cascade should handle this, but be explicit)
      await _db.execute(
        '''
        DELETE FROM session_set_logs
        WHERE block_id = ? AND exercise_id = ?
        ''',
        [siblingId, exerciseId],
      );

      // Delete exercise from block
      await _db.execute(
        '''
        DELETE FROM session_block_exercises
        WHERE block_id = ? AND exercise_id = ?
        ''',
        [siblingId, exerciseId],
      );
    }

    // Update session updated_at
    await _db.execute('UPDATE sessions SET updated_at = ? WHERE id = ?', [
      DateTime.now().toIso8601String(),
      session.id,
    ]);

    return fetchSessionById(session.id);
  }

  /// Find sibling block IDs (blocks that share rounds).
  Set<String> _findSiblingBlockIds(Session session, SessionBlock target) {
    if (target.totalRounds == null) return {target.id};
    return session.blocks
        .where(
          (b) => b.type == target.type && b.totalRounds == target.totalRounds,
        )
        .map((b) => b.id)
        .toSet();
  }
}

@riverpod
SessionRepositoryPowerSync sessionRepositoryPowerSync(Ref ref) {
  final dbAsync = ref.watch(powerSyncDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  final templateRepo = ref.watch(templateRepositoryPowerSyncProvider);
  return SessionRepositoryPowerSync(db, templateRepo);
}
