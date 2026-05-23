import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';

/// Single source of truth for writing into the `exercises` library table.
///
/// Used by both the template path (when inserting block exercises) and the
/// active-session path (when an AI suggestion proposes a brand-new exercise
/// during mid-session replacement). Centralising the upsert avoids divergence
/// between the two paths.
class LibraryExerciseStore {
  LibraryExerciseStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  /// Ensures [exercise] exists in the `exercises` table and returns the
  /// canonical id to use when referencing it.
  ///
  /// If a row with the same `name` already exists, that row's id is reused
  /// (and the row is updated with the supplied fields). Otherwise the
  /// supplied [exercise.id] is used as the new row id.
  Future<String> upsert(WorkoutExercise exercise, {String? now}) async {
    final timestamp = now ?? DateTime.now().toIso8601String();
    final existingRow = await _powerSync.getOptional(
      'SELECT id FROM exercises WHERE name = ?',
      [exercise.name],
    );
    final canonicalId = existingRow?['id'] as String? ?? exercise.id;

    await _powerSync.upsert('exercises', {
      'id': canonicalId,
      'name': exercise.name,
      'modality': exercise.modality.name,
      'equipment': exercise.equipment ?? '',
      'set_metrics_style': exercise.setMetricsStyle.name,
      'cues': jsonEncode(exercise.cues),
      'benefits': ExerciseBenefit.listToJsonString(exercise.benefits),
      'is_unilateral': exercise.isUnilateral ? 1 : 0,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    return canonicalId;
  }
}
