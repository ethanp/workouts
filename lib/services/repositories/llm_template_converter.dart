import 'package:uuid/uuid.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';

const _uuid = Uuid();

WorkoutTemplate templateFromLlmOption(LlmWorkoutOption option) {
  final blocks = option.blocks.map(_blockFromLlmBlock).toList();

  return WorkoutTemplate(
    id: _uuid.v4(),
    name: option.title,
    goal: option.goal,
    blocks: blocks,
    notes: option.rationale,
  );
}

WorkoutBlock _blockFromLlmBlock(LlmWorkoutBlock blockOption) {
  final exercises = blockOption.exercises.map(_exerciseFromLlmExercise).toList();

  return WorkoutBlock(
    id: _uuid.v4(),
    title: blockOption.title,
    type: WorkoutBlockType.values.firstWhere(
      (t) => t.name == blockOption.type,
      orElse: () => WorkoutBlockType.strength,
    ),
    targetDuration: Duration(minutes: blockOption.estimatedMinutes),
    exercises: exercises,
    description: blockOption.description ?? '',
    rounds: blockOption.rounds,
  );
}

WorkoutExercise _exerciseFromLlmExercise(LlmExercise llmExercise) {
  final sets = int.tryParse(llmExercise.sets ?? '') ?? 1;
  final parts = <String>[];
  if (llmExercise.sets != null && llmExercise.sets!.isNotEmpty) {
    parts.add('${llmExercise.sets} ×');
  }
  if (llmExercise.reps != null && llmExercise.reps!.isNotEmpty) {
    parts.add(llmExercise.reps!);
  } else if (llmExercise.duration != null && llmExercise.duration!.isNotEmpty) {
    parts.add(llmExercise.duration!);
  }
  final prescription = parts.join(' ');

  return WorkoutExercise(
    id: _uuid.v4(),
    name: llmExercise.name,
    modality: llmExercise.duration != null
        ? ExerciseModality.timed
        : ExerciseModality.reps,
    prescription: prescription,
    targetSets: sets,
    cues: llmExercise.notes != null ? [llmExercise.notes!] : const [],
  );
}
