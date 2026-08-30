import 'package:workouts/models/llm_workout_option.dart';

class const LlmFollowupPrompt({
  required final String systemPrompt,
  required final String userPrompt,
}) {
  factory forQuestion({
    required LlmWorkoutResponse workoutResponse,
    required String question,
  }) {
    final workoutSummary = StringBuffer();
    for (final option in workoutResponse.options) {
      workoutSummary.writeln('## ${option.title} (${option.goal})');
      workoutSummary.writeln(option.rationale);
      for (final block in option.blocks) {
        workoutSummary.writeln(
          '- ${block.title} (${block.estimatedMinutes}min): '
          '${block.exercises.map((exercise) => exercise.name).join(', ')}',
        );
      }
      workoutSummary.writeln();
    }

    return LlmFollowupPrompt(
      systemPrompt:
          'You are a personal fitness coach. The user just received AI-generated '
          'workout options. Answer their question conversationally and concisely. '
          'Do not use markdown formatting. Keep answers under 200 words.',
      userPrompt:
          'Here are the workout options I was given:\n\n'
          '$workoutSummary\n'
          'My question: $question',
    );
  }
}
