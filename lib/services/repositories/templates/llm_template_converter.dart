import 'package:ethan_utils/ethan_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';

const _uuid = Uuid();

WorkoutTemplate templateFromLlmOption(LlmWorkoutOption option) {
  final blocks = option.blocks.mapL(_blockFromLlmBlock);

  return WorkoutTemplate(
    id: _uuid.v4(),
    name: option.title,
    goal: option.goal,
    blocks: blocks,
    notes: option.rationale,
  );
}

WorkoutBlock _blockFromLlmBlock(LlmWorkoutBlock blockOption) {
  final exercises = blockOption.exercises.mapL(_exerciseFromLlmExercise);

  return WorkoutBlock(
    id: _uuid.v4(),
    title: blockOption.title,
    type: WorkoutBlockType.values.firstWhere(
      (workoutBlockType) => workoutBlockType.name == blockOption.type,
      orElse: () => WorkoutBlockType.strength,
    ),
    targetDuration: Duration(minutes: blockOption.estimatedMinutes),
    exercises: exercises,
    description: blockOption.description ?? '',
    rounds: blockOption.rounds,
  );
}

WorkoutExercise _exerciseFromLlmExercise(LlmExercise llmExercise) {
  final plannedSets = llmExercise.plannedSets;
  return WorkoutExercise(
    id: _uuid.v4(),
    name: llmExercise.name,
    modality: llmExercise.modality,
    prescription: llmExercise.prescription,
    targetSets: plannedSets.isEmpty ? 1 : plannedSets.length,
    setMetricsStyle:
        llmExercise.setMetricsStyle ??
        inferSetMetricsStyle(
          modality: llmExercise.modality,
          plannedSets: plannedSets,
        ),
    restDuration: llmExercise.restSeconds == null
        ? null
        : Duration(seconds: llmExercise.restSeconds!),
    cues: llmExercise.notes != null ? [llmExercise.notes!] : const [],
    plannedSets: plannedSets,
    isUnilateral: llmExercise.isUnilateral,
  );
}
