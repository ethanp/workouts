import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/powersync/powersync_mappers.dart' as mappers;

class TemplateHydrator {
  TemplateHydrator(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<String>> fetchExerciseNames() async {
    final exerciseNameRows = await _powerSync.getAll(
      'SELECT DISTINCT name FROM exercises ORDER BY name',
    );
    return exerciseNameRows.mapL(
      (exerciseNameRow) => exerciseNameRow['name'] as String,
    );
  }

  Future<List<WorkoutTemplate>> hydrateTemplates(
    List<Map<String, dynamic>> templateRows,
  ) async {
    final templates = <WorkoutTemplate>[];
    for (final templateRow in templateRows) {
      final templateId = templateRow['id'] as String;
      final blocks = await hydrateBlocks(templateId);
      templates.add(mappers.workoutTemplateFromRow(templateRow, blocks));
    }
    return templates;
  }

  Future<List<WorkoutBlock>> hydrateBlocks(String templateId) async {
    final blockRows = await _powerSync.getAll(
      'SELECT * FROM workout_blocks WHERE template_id = ? ORDER BY block_index',
      [templateId],
    );
    final blocks = <WorkoutBlock>[];
    for (final blockRow in blockRows) {
      final blockId = blockRow['id'] as String;
      final exercises = await hydrateExercises(blockId);
      blocks.add(mappers.workoutBlockFromRow(blockRow, exercises));
    }
    return blocks;
  }

  Future<List<WorkoutExercise>> hydrateExercises(String blockId) async {
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
        wbe.planned_sets as wbe_planned_sets,
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
    return exerciseRows.mapL(
      (exerciseJoinRow) => mappers.workoutExerciseFromJoinRow(exerciseJoinRow),
    );
  }
}
