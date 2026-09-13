import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/fitness_goal.dart';

class const LlmExerciseBenefitsPrompt({
  required final String systemPrompt,
  required final String userPrompt,
}) {
  factory forExercise({
    required String exerciseName,
    String? exerciseNotes,
    required List<FitnessGoal> activeGoals,
  }) {
    final goalsJson = activeGoals.mapL(
      (goal) => {
        'id': goal.id,
        'title': goal.title,
        'category': goal.category.name,
        if (goal.description.isNotEmpty) 'description': goal.description,
      },
    );

    final userPrompt = StringBuffer()
      ..writeln('Exercise: $exerciseName')
      ..writeln(exerciseNotes != null ? 'Notes: $exerciseNotes' : '')
      ..writeln()
      ..writeln('User goals:')
      ..writeln(jsonEncode(goalsJson));

    return LlmExerciseBenefitsPrompt(
      systemPrompt: _systemPrompt,
      userPrompt: userPrompt.toString(),
    );
  }

  static const _systemPrompt = '''You are an expert exercise physiologist.
Given an exercise name (and optional notes), enumerate its distinct physiological benefits.
For each benefit, identify which of the provided user goals it directly and meaningfully serves.
Be conservative: only link a benefit to a goal when the connection is direct and specific, not broad or speculative.
A benefit that serves no goal should still be listed — it is informational.

Respond with valid JSON only, no markdown. Structure:
{
  "benefits": [
    { "name": "string (concise benefit label)", "goalIds": ["goal_id", ...] }
  ]
}''';
}
