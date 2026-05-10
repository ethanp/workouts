import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

const _uuid = Uuid();

class SessionMaterializer {
  SessionMaterializer(this._powerSync, this._templateRepository);

  final PowerSyncDatabase _powerSync;
  final TemplateRepositoryPowerSync _templateRepository;

  Future<Session> startSession(String templateId) async {
    final templates = await _templateRepository.fetchTemplates();
    final template = templates.firstWhere(
      (workoutTemplate) => workoutTemplate.id == templateId,
    );

    final sessionId = _uuid.v4();
    final now = DateTime.now();
    final nowUtcText = now.toUtc().toIso8601String();

    await _insertSessionRow(sessionId, templateId, nowUtcText);
    final blocks = await _materializeBlocks(sessionId, template.blocks);

    return Session(
      id: sessionId,
      templateId: templateId,
      startedAt: now,
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
    final sessionBlocks = <SessionBlock>[];
    var blockIndex = 0;

    for (final templateBlock in templateBlocks) {
      final totalRounds = templateBlock.rounds <= 0 ? 1 : templateBlock.rounds;
      final hasMultipleRounds = totalRounds > 1;

      for (var roundIndex = 0; roundIndex < totalRounds; roundIndex++) {
        final block = await _materializeSingleBlock(
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
    final blockId = _uuid.v4();

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
    for (
      var exerciseIndex = 0;
      exerciseIndex < exercises.length;
      exerciseIndex++
    ) {
      final exercise = exercises[exerciseIndex];
      await _powerSync.execute(
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
          exerciseIndex,
          exercise.prescription,
          PlannedSet.listToJsonString(exercise.plannedSets),
          exercise.setupDuration?.inSeconds,
          exercise.workDuration?.inSeconds,
          exercise.restDuration?.inSeconds,
        ],
      );
    }
  }
}
