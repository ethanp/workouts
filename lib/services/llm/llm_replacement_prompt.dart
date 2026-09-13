import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/workout_exercise.dart';

class const LlmReplacementPrompt({
  required final String systemPrompt,
  required final String userPrompt,
}) {
  factory forExercise({
    required WorkoutExercise originalExercise,
    String? availableEquipment,
    required List<FitnessGoal> activeGoals,
    required List<WorkoutExercise> libraryExercises,
    Set<String> excludeIds = const {},
  }) {
    final selectableLibrary = libraryExercises.whereL(
      (exercise) =>
          exercise.id != originalExercise.id &&
          !excludeIds.contains(exercise.id),
    );

    final userPrompt = StringBuffer()
      ..writeln('Original exercise to replace:')
      ..writeln(jsonEncode(_originalExerciseJson(originalExercise)))
      ..writeln();
    _writeAvailableEquipment(userPrompt, availableEquipment);
    userPrompt
      ..writeln('Active user goals:')
      ..writeln(jsonEncode(activeGoals.mapL(_goalPromptJson)))
      ..writeln()
      ..writeln(
        'Existing library exercises (prefer these when a good match exists):',
      )
      ..writeln(jsonEncode(selectableLibrary.mapL(_libraryExerciseJson)));

    return LlmReplacementPrompt(
      systemPrompt: _systemPrompt,
      userPrompt: userPrompt.toString(),
    );
  }

  static void _writeAvailableEquipment(
    StringBuffer buffer,
    String? availableEquipment,
  ) {
    if (availableEquipment == null || availableEquipment.trim().isEmpty) {
      return;
    }
    buffer
      ..writeln('Available equipment in current location:')
      ..writeln(availableEquipment)
      ..writeln();
  }

  static Map<String, Object?> _goalPromptJson(FitnessGoal goal) => {
    'id': goal.id,
    'title': goal.title,
    'category': goal.category.name,
    if (goal.description.isNotEmpty) 'description': goal.description,
  };

  static Map<String, Object?> _libraryExerciseJson(WorkoutExercise exercise) =>
      {
        'id': exercise.id,
        'name': exercise.name,
        'modality': exercise.modality.name,
        if (exercise.equipment != null && exercise.equipment!.isNotEmpty)
          'equipment': exercise.equipment,
        if (exercise.benefits.isNotEmpty)
          'benefits': exercise.benefits.mapL((benefit) => benefit.name),
      };

  static Map<String, Object?> _originalExerciseJson(
    WorkoutExercise originalExercise,
  ) => {
    'name': originalExercise.name,
    'modality': originalExercise.modality.name,
    'prescription': originalExercise.prescription,
    'set_metrics_style': originalExercise.setMetricsStyle.name,
    if (originalExercise.equipment != null &&
        originalExercise.equipment!.isNotEmpty)
      'equipment': originalExercise.equipment,
    if (originalExercise.benefits.isNotEmpty)
      'benefits': originalExercise.benefits.mapL((benefit) => benefit.name),
    if (originalExercise.cues.isNotEmpty) 'cues': originalExercise.cues,
  };

  static const _systemPrompt = '''You are an expert strength and conditioning coach helping a user swap an exercise mid-workout.

The user is in an active session and wants a substitute for one specific exercise — usually because the equipment is taken, an injury flared up, or they want a similar movement with what they have on hand.

Suggest up to 5 alternatives that:
- Train similar movement patterns and target similar benefits to the original
- Fit the available equipment when provided
- Stay aligned with the user's active goals
- Are reasonable swaps for the same slot in a session (similar effort cost / similar movement category)

Prefer existing library exercises whenever a suitable match exists — reference them by their library id. Only propose a brand-new exercise when nothing in the library is a good fit.

Respond with valid JSON only, no markdown. Structure:
{
  "suggestions": [
    {
      "library_exercise_id": "<existing library id or null>",
      "reason": "one short sentence on why this is a good substitute",
      "name": "<required when library_exercise_id is null>",
      "modality": "reps|timed|hold|mobility|breath",
      "equipment": "string or null",
      "prescription": "e.g. '3 x 10' or '3 x 30s'",
      "set_metrics_style": "repsOnly|repsAndWeight|durationOnly|repsAndDuration",
      "target_sets": 3,
      "cues": ["short coaching cue", ...],
      "benefits": [
        { "name": "benefit label", "goalIds": ["goal_id", ...] }
      ]
    }
  ]
}

When `library_exercise_id` is non-null, the other fields can be omitted — the existing row will be used.''';
}
