import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';

const _uuid = Uuid();

class TemplateExerciseStore {
  TemplateExerciseStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> insertBlockExercises(
    String blockId,
    List<WorkoutExercise> exercises,
    String now,
  ) async {
    for (
      var exerciseIndex = 0;
      exerciseIndex < exercises.length;
      exerciseIndex++
    ) {
      final exercise = exercises[exerciseIndex];
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
          id, block_id, exercise_id, exercise_index, prescription, planned_sets,
          setup_duration_seconds, work_duration_seconds, rest_duration_seconds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          blockId,
          exerciseId,
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

  Future<void> cleanOrphanedBlockExercises() async {
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
}
