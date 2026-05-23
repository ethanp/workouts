import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/repositories/library_exercise_store.dart';

const _uuid = Uuid();

class TemplateExerciseStore {
  TemplateExerciseStore(this._powerSync)
    : _libraryExerciseStore = LibraryExerciseStore(_powerSync);

  final PowerSyncDatabase _powerSync;
  final LibraryExerciseStore _libraryExerciseStore;

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
      final canonicalExerciseId = await _libraryExerciseStore.upsert(
        exercise,
        now: now,
      );

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
          canonicalExerciseId,
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

  /// Overwrites the planned-set list for one exercise within one template
  /// block, and bumps the parent template's `updated_at` so any active
  /// `watchTemplates()` subscription re-emits with the change.
  Future<void> updatePlannedSets({
    required String templateId,
    required String blockId,
    required String exerciseId,
    required List<PlannedSet> plannedSets,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _powerSync.execute(
      '''
      UPDATE workout_block_exercises
      SET planned_sets = ?
      WHERE block_id = ? AND exercise_id = ?
      ''',
      [PlannedSet.listToJsonString(plannedSets), blockId, exerciseId],
    );
    await _powerSync.execute(
      'UPDATE workout_templates SET updated_at = ? WHERE id = ?',
      [now, templateId],
    );
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
