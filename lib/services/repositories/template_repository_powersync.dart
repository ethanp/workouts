import 'dart:async';
import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';
import 'package:workouts/services/powersync/powersync_mappers.dart' as mappers;
import 'package:workouts/services/repositories/llm_template_converter.dart'
    as llm;
import 'package:workouts/services/repositories/seed_templates.dart'
    as seeds;

part 'template_repository_powersync.g.dart';

const _uuid = Uuid();

class TemplateRepositoryPowerSync {
  TemplateRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;

  static const int currentTemplateVersion = 5;

  Future<List<String>> fetchExerciseNames() async {
    final exerciseNameRows = await _powerSync.getAll(
      'SELECT DISTINCT name FROM exercises ORDER BY name',
    );
    return exerciseNameRows.mapL((exerciseNameRow) => exerciseNameRow['name'] as String);
  }

  Future<List<WorkoutTemplate>> fetchTemplates() async {
    await _cleanOrphanedBlockExercises();

    final templateRows = await _powerSync.getAll(
      'SELECT * FROM workout_templates ORDER BY created_at DESC',
    );
    if (templateRows.isEmpty) {
      return _reseedTemplates();
    }
    return _hydrateTemplates(templateRows);
  }

  Stream<List<WorkoutTemplate>> watchTemplates() {
    return _powerSync
        .watch('SELECT * FROM workout_templates ORDER BY created_at DESC')
        .asyncMap(_hydrateTemplates);
  }

  Future<void> saveTemplate(WorkoutTemplate template) async {
    final now = DateTime.now().toIso8601String();

    await _powerSync.upsert('workout_templates', {
      'id': template.id,
      'name': template.name,
      'goal': template.goal,
      'notes': template.notes ?? '',
      'created_at': template.createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    });

    await _powerSync.execute(
      'DELETE FROM workout_blocks WHERE template_id = ?',
      [template.id],
    );

    for (var blockIndex = 0; blockIndex < template.blocks.length; blockIndex++) {
      final block = template.blocks[blockIndex];
      final blockId = block.id.isEmpty ? _uuid.v4() : block.id;
      await _insertBlock(template.id, blockId, blockIndex, block, now);
      await _insertBlockExercises(blockId, block.exercises, now);
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    await _powerSync.execute(
      'DELETE FROM workout_templates WHERE id = ?',
      [templateId],
    );
  }

  Future<WorkoutTemplate> createFromLlmOption(LlmWorkoutOption option) async {
    final template = llm.templateFromLlmOption(option);
    await saveTemplate(template);
    return template;
  }

  Future<void> reseedTemplates() async {
    await _powerSync.execute('DELETE FROM workout_block_exercises');
    await _powerSync.execute('DELETE FROM workout_blocks');
    await _powerSync.execute('DELETE FROM workout_templates');
    await _reseedTemplates();
  }

  Future<List<WorkoutTemplate>> _hydrateTemplates(
    List<Map<String, dynamic>> templateRows,
  ) async {
    final templates = <WorkoutTemplate>[];
    for (final templateRow in templateRows) {
      final templateId = templateRow['id'] as String;
      final blocks = await _hydrateBlocks(templateId);
      templates.add(mappers.workoutTemplateFromRow(templateRow, blocks));
    }
    return templates;
  }

  Future<List<WorkoutBlock>> _hydrateBlocks(String templateId) async {
    final blockRows = await _powerSync.getAll(
      'SELECT * FROM workout_blocks WHERE template_id = ? ORDER BY block_index',
      [templateId],
    );
    final blocks = <WorkoutBlock>[];
    for (final blockRow in blockRows) {
      final blockId = blockRow['id'] as String;
      final exercises = await _hydrateExercises(blockId);
      blocks.add(mappers.workoutBlockFromRow(blockRow, exercises));
    }
    return blocks;
  }

  Future<List<WorkoutExercise>> _hydrateExercises(String blockId) async {
    final exerciseRows = await _powerSync.getAll(
      '''
      SELECT
        e.id as e_id,
        e.name as e_name,
        e.modality as e_modality,
        e.equipment as e_equipment,
        e.cues as e_cues,
        e.benefits as e_benefits,
        wbe.prescription as wbe_prescription,
        wbe.setup_duration_seconds as wbe_setup_duration_seconds,
        wbe.work_duration_seconds as wbe_work_duration_seconds,
        wbe.rest_duration_seconds as wbe_rest_duration_seconds
      FROM workout_block_exercises wbe
      INNER JOIN exercises e ON e.id = wbe.exercise_id
      WHERE wbe.block_id = ?
      ORDER BY wbe.exercise_index
      ''',
      [blockId],
    );
    return exerciseRows
        .mapL((exerciseJoinRow) => mappers.workoutExerciseFromJoinRow(exerciseJoinRow));
  }

  Future<void> _insertBlock(
    String templateId,
    String blockId,
    int blockIndex,
    WorkoutBlock block,
    String now,
  ) async {
    await _powerSync.execute(
      '''
      INSERT INTO workout_blocks (
        id, template_id, block_index, type, title,
        target_duration_seconds, description, rounds
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        blockId,
        templateId,
        blockIndex,
        block.type.name,
        block.title,
        block.targetDuration.inSeconds,
        block.description,
        block.rounds,
      ],
    );
  }

  Future<void> _insertBlockExercises(
    String blockId,
    List<WorkoutExercise> exercises,
    String now,
  ) async {
    for (var exerciseIndex = 0; exerciseIndex < exercises.length; exerciseIndex++) {
      final exercise = exercises[exerciseIndex];

      // Reuse existing exercise ID if one with the same name exists,
      // preventing server-side UNIQUE(name) conflicts that orphan
      // workout_block_exercises rows after sync.
      final existingRow = await _powerSync.getOptional(
        'SELECT id FROM exercises WHERE name = ?',
        [exercise.name],
      );
      final exerciseId = existingRow?['id'] as String? ?? exercise.id;

      await _powerSync.upsert('exercises', {
        'id': exerciseId,
        'name': exercise.name,
        'modality': exercise.modality.name,
        'equipment': exercise.equipment ?? '',
        'cues': jsonEncode(exercise.cues),
        'benefits': ExerciseBenefit.listToJsonString(exercise.benefits),
        'created_at': now,
        'updated_at': now,
      });

      await _powerSync.execute(
        '''
        INSERT INTO workout_block_exercises (
          id, block_id, exercise_id, exercise_index, prescription,
          setup_duration_seconds, work_duration_seconds, rest_duration_seconds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          blockId,
          exerciseId,
          exerciseIndex,
          exercise.prescription,
          exercise.setupDuration?.inSeconds,
          exercise.workDuration?.inSeconds,
          exercise.restDuration?.inSeconds,
        ],
      );
    }
  }

  Future<void> _cleanOrphanedBlockExercises() async {
    // Skip cleanup if exercises haven't synced yet. An empty exercises table
    // means PowerSync is still initializing — deleting junction rows now would
    // permanently orphan them once exercises arrive.
    final exerciseCountRow = await _powerSync.getOptional(
      'SELECT COUNT(*) as count FROM exercises',
    );
    final exerciseCount = exerciseCountRow?['count'] as int? ?? 0;
    if (exerciseCount == 0) return;

    await _powerSync.execute('''
      DELETE FROM workout_block_exercises
      WHERE exercise_id NOT IN (SELECT id FROM exercises)
    ''');
    await _powerSync.execute('''
      DELETE FROM session_block_exercises
      WHERE exercise_id NOT IN (SELECT id FROM exercises)
    ''');
  }

  /// Updates only the benefits column for an exercise by ID.
  /// Preserves all other exercise fields (name, modality, cues, etc.).
  Future<void> updateExerciseBenefits(
    String exerciseId,
    List<ExerciseBenefit> benefits,
  ) async {
    await _powerSync.execute(
      'UPDATE exercises SET benefits = ?, updated_at = ? WHERE id = ?',
      [
        ExerciseBenefit.listToJsonString(benefits),
        DateTime.now().toIso8601String(),
        exerciseId,
      ],
    );
  }

  Future<List<WorkoutTemplate>> _reseedTemplates() async {
    final templates = seeds.buildSeedTemplates();
    for (final template in templates) {
      await saveTemplate(template);
    }
    return templates;
  }
}

@riverpod
TemplateRepositoryPowerSync templateRepositoryPowerSync(Ref ref) {
  final powerSyncDatabaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = powerSyncDatabaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return TemplateRepositoryPowerSync(powerSyncDatabase);
}
