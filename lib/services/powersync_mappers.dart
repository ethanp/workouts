import 'dart:convert';

import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';

/// Parse targetSets from prescription string.
/// Formats: "3 × 8" -> 3, "5 per side" -> 1, "3 × 5 per side" -> 3
int parseTargetSetsFromPrescription(String prescription) {
  // Look for "N ×" pattern at the start
  final match = RegExp(r'^(\d+)\s*×').firstMatch(prescription);
  if (match != null) {
    return int.parse(match.group(1)!);
  }
  // Default to 1 if no × pattern found
  return 1;
}

/// Map normalized exercise row to WorkoutExercise model.
WorkoutExercise exerciseFromRow(Map<String, dynamic> row) {
  final modalityStr = row['modality'] as String;
  final modality = ExerciseModality.values.firstWhere(
    (e) => e.name == modalityStr,
    orElse: () => ExerciseModality.reps,
  );

  final cuesJson = row['cues'] as String?;
  final cues = cuesJson != null
      ? (jsonDecode(cuesJson) as List).cast<String>()
      : <String>[];

  final prescription = row['prescription'] as String? ?? '';

  return WorkoutExercise(
    id: row['id'] as String,
    name: row['name'] as String,
    modality: modality,
    prescription: prescription,
    targetSets: parseTargetSetsFromPrescription(prescription),
    equipment: row['equipment'] as String?,
    cues: cues,
    setupDuration: row['setup_duration_seconds'] != null
        ? Duration(seconds: row['setup_duration_seconds'] as int)
        : null,
    workDuration: row['work_duration_seconds'] != null
        ? Duration(seconds: row['work_duration_seconds'] as int)
        : null,
    restDuration: row['rest_duration_seconds'] != null
        ? Duration(seconds: row['rest_duration_seconds'] as int)
        : null,
  );
}

/// Map normalized workout_block_exercises row to WorkoutExercise.
/// This includes exercise data joined with block-specific prescription/durations.
WorkoutExercise workoutExerciseFromJoinRow(Map<String, dynamic> row) {
  final modalityStr = row['e_modality'] as String;
  final modality = ExerciseModality.values.firstWhere(
    (e) => e.name == modalityStr,
    orElse: () => ExerciseModality.reps,
  );

  final cuesJson = row['e_cues'] as String?;
  final cues = cuesJson != null
      ? (jsonDecode(cuesJson) as List).cast<String>()
      : <String>[];

  final prescription = row['wbe_prescription'] as String? ?? '';

  return WorkoutExercise(
    id: row['e_id'] as String,
    name: row['e_name'] as String,
    modality: modality,
    prescription: prescription,
    targetSets: parseTargetSetsFromPrescription(prescription),
    equipment: row['e_equipment'] as String?,
    cues: cues,
    setupDuration: row['wbe_setup_duration_seconds'] != null
        ? Duration(seconds: row['wbe_setup_duration_seconds'] as int)
        : null,
    workDuration: row['wbe_work_duration_seconds'] != null
        ? Duration(seconds: row['wbe_work_duration_seconds'] as int)
        : null,
    restDuration: row['wbe_rest_duration_seconds'] != null
        ? Duration(seconds: row['wbe_rest_duration_seconds'] as int)
        : null,
  );
}

/// Map normalized session_block_exercises row to WorkoutExercise.
WorkoutExercise sessionExerciseFromJoinRow(Map<String, dynamic> row) {
  final modalityStr = row['e_modality'] as String;
  final modality = ExerciseModality.values.firstWhere(
    (e) => e.name == modalityStr,
    orElse: () => ExerciseModality.reps,
  );

  final cuesJson = row['e_cues'] as String?;
  final cues = cuesJson != null
      ? (jsonDecode(cuesJson) as List).cast<String>()
      : <String>[];

  final prescription = row['sbe_prescription'] as String? ?? '';

  return WorkoutExercise(
    id: row['e_id'] as String,
    name: row['e_name'] as String,
    modality: modality,
    prescription: prescription,
    targetSets: parseTargetSetsFromPrescription(prescription),
    equipment: row['e_equipment'] as String?,
    cues: cues,
    setupDuration: row['sbe_setup_duration_seconds'] != null
        ? Duration(seconds: row['sbe_setup_duration_seconds'] as int)
        : null,
    workDuration: row['sbe_work_duration_seconds'] != null
        ? Duration(seconds: row['sbe_work_duration_seconds'] as int)
        : null,
    restDuration: row['sbe_rest_duration_seconds'] != null
        ? Duration(seconds: row['sbe_rest_duration_seconds'] as int)
        : null,
  );
}

/// Map normalized workout_blocks row to WorkoutBlock model.
WorkoutBlock workoutBlockFromRow(
  Map<String, dynamic> blockRow,
  List<WorkoutExercise> exercises,
) {
  final typeStr = blockRow['type'] as String;
  final type = WorkoutBlockType.values.firstWhere(
    (e) => e.name == typeStr,
    orElse: () => WorkoutBlockType.strength,
  );

  return WorkoutBlock(
    id: blockRow['id'] as String,
    type: type,
    title: blockRow['title'] as String,
    targetDuration: Duration(
      seconds: blockRow['target_duration_seconds'] as int,
    ),
    exercises: exercises,
    description: blockRow['description'] as String? ?? '',
    rounds: blockRow['rounds'] as int? ?? 1,
  );
}

/// Map normalized workout_templates row to WorkoutTemplate model.
WorkoutTemplate workoutTemplateFromRow(
  Map<String, dynamic> templateRow,
  List<WorkoutBlock> blocks,
) {
  return WorkoutTemplate(
    id: templateRow['id'] as String,
    name: templateRow['name'] as String,
    goal: templateRow['goal'] as String,
    blocks: blocks,
    createdAt: templateRow['created_at'] != null
        ? DateTime.parse(templateRow['created_at'] as String)
        : null,
    updatedAt: templateRow['updated_at'] != null
        ? DateTime.parse(templateRow['updated_at'] as String)
        : null,
    notes: templateRow['notes'] as String?,
  );
}

/// Map normalized session_set_logs row to SessionSetLog model.
SessionSetLog sessionSetLogFromRow(Map<String, dynamic> row) {
  return SessionSetLog(
    id: row['id'] as String,
    sessionBlockId: row['block_id'] as String,
    exerciseId: row['exercise_id'] as String,
    setIndex: row['set_index'] as int,
    weightKg: row['weight_kg'] as double?,
    reps: row['reps'] as int?,
    duration: row['duration_seconds'] != null
        ? Duration(seconds: row['duration_seconds'] as int)
        : null,
    unitRemaining: row['unit_remaining'] as int?,
  );
}

/// Map normalized session_blocks row to SessionBlock model.
SessionBlock sessionBlockFromRow(
  Map<String, dynamic> blockRow,
  List<WorkoutExercise> exercises,
  List<SessionSetLog> logs,
) {
  final typeStr = blockRow['type'] as String;
  final type = WorkoutBlockType.values.firstWhere(
    (e) => e.name == typeStr,
    orElse: () => WorkoutBlockType.strength,
  );

  return SessionBlock(
    id: blockRow['id'] as String,
    sessionId: blockRow['session_id'] as String,
    type: type,
    blockIndex: blockRow['block_index'] as int,
    exercises: exercises,
    logs: logs,
    targetDuration: Duration(
      seconds: blockRow['target_duration_seconds'] as int,
    ),
    actualDuration: blockRow['actual_duration_seconds'] != null
        ? Duration(seconds: blockRow['actual_duration_seconds'] as int)
        : null,
    notes: blockRow['notes'] as String?,
    roundIndex: blockRow['round_index'] as int?,
    totalRounds: blockRow['total_rounds'] as int?,
  );
}

/// Map normalized sessions row to Session model.
Session sessionFromRow(
  Map<String, dynamic> sessionRow,
  List<SessionBlock> blocks,
) {
  return Session(
    id: sessionRow['id'] as String,
    templateId: sessionRow['template_id'] as String,
    startedAt: DateTime.parse(sessionRow['started_at'] as String),
    completedAt: sessionRow['completed_at'] != null
        ? DateTime.parse(sessionRow['completed_at'] as String)
        : null,
    duration: sessionRow['duration_seconds'] != null
        ? Duration(seconds: sessionRow['duration_seconds'] as int)
        : null,
    notes: sessionRow['notes'] as String?,
    blocks: blocks,
    isPaused: false, // Not in normalized schema, defaults to false
    pausedAt: sessionRow['paused_at'] != null
        ? DateTime.parse(sessionRow['paused_at'] as String)
        : null,
    totalPausedDuration: Duration(
      seconds: sessionRow['total_paused_duration_seconds'] as int? ?? 0,
    ),
    updatedAt: sessionRow['updated_at'] != null
        ? DateTime.parse(sessionRow['updated_at'] as String)
        : null,
  );
}

/// Format a duration for display (e.g. "1h 30m" or "5m 30s").
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

/// Format a duration for timer display (e.g. "01:30:45" or "05:30").
String formatDurationTimer(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final hours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes.remainder(60);
  final seconds = safeDuration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
