import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/run_formatting.dart';

/// Builds the system prompt for the per-exercise chat.
///
/// Pure formatter: takes a [WorkoutExercise] and emits the lines that frame
/// the conversation for the LLM. Kept as a class (not a free function) so a
/// future variant — e.g. seeding with the user's fitness goals — can extend
/// it without changing call sites.
class ExerciseChatPromptBuilder {
  const ExerciseChatPromptBuilder();

  String buildSystemPrompt(WorkoutExercise exercise) {
    final lines = <String>[
      'You are a knowledgeable strength and conditioning coach.',
      'The user is asking about this specific exercise:',
      '',
      '- Name: ${exercise.name}',
      '- Modality: ${exercise.modality.name}',
      '- Prescription: ${exercise.prescriptionLabel}',
      if (exercise.equipment != null && exercise.equipment!.isNotEmpty)
        '- Equipment: ${exercise.equipment}',
      if (exercise.restDuration != null)
        '- Planned rest: ${Format.restDuration(exercise.restDuration!)}',
      if (exercise.cues.isNotEmpty) ...[
        '- Coaching cues:',
        ...exercise.cues.map((cue) => '  - $cue'),
      ],
      if (exercise.benefits.isNotEmpty) ...[
        '- Benefits:',
        ...exercise.benefits.map((benefit) => '  - ${benefit.name}'),
      ],
      '',
      'Answer concisely (a few short paragraphs at most). Prefer specific, '
          'actionable cues over generic theory.',
      'If the user reports pain that is severe, persistent, sharp, '
          'accompanied by swelling, numbness, or radiates, recommend they '
          'consult a clinician before continuing. Otherwise give practical '
          'form fixes and reasonable modifications.',
    ];
    return lines.join('\n');
  }
}
