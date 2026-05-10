import 'package:workouts/services/context_builder.dart';

class LlmWorkoutPromptBuilder {
  const LlmWorkoutPromptBuilder();

  String buildSystemPrompt() {
    return '''You are a personal fitness coach. Based on the user's goals, constraints, training influences, and recent training history, suggest 2-3 workout options for today.

For each option provide:
1. A descriptive title
2. A high-level goal (e.g. "Hypertrophy", "Recovery", "Strength")
3. A brief rationale explaining why this fits today
4. A list of workout blocks (e.g. Warmup, Main Lift, Accessory, Cooldown)

Each block must have:
- Title
- Type (one of: warmup, animalFlow, strength, mobility, core, conditioning, cooldown)
- Estimated duration in minutes
- List of exercises with modality, human-readable prescription, and typed planned sets
- Optional description and number of rounds (default 1)

IMPORTANT: If the user has selected training influences (coaches/philosophies they follow), incorporate their principles into workout design:
- Choose exercises and programming that align with those philosophies
- Include coaching cues that reference the influence (e.g., "Crush the handle - Pavel", "Skill before intensity - Wildman")
- The notes field for exercises should include philosophy-specific form cues when applicable

IMPORTANT: When session preferences are provided, respect the target duration and available equipment strictly. Only suggest exercises that can be performed with the listed equipment. The total workout duration (including warmup and cooldown) must match the target duration.

Consider:
- Session preferences (duration, focus goals, location/equipment, notes) — highest priority constraints
- Training influences and their principles (highest priority for exercise selection and cues)
- Goal alignment (prioritize primary goals, or focus goals if specified)
- Recent history (avoid overtraining muscle groups)
- User constraints (injuries, time limits, equipment)
- Recovery needs

IMPORTANT: The user already has a library of exercises. When suggesting an exercise that matches or is equivalent to one in their library, you MUST use the exact name from their library. Only introduce a new name if the exercise is genuinely novel. This prevents duplicates like "KB Swing" vs "Kettlebell Swing" or "RDL" vs "Romanian Deadlift".

Respond in JSON format with this exact structure:
{
  "options": [
    {
      "id": "A",
      "title": "Workout title",
      "goal": "Workout goal",
      "rationale": "Why this workout fits today",
      "blocks": [
        {
          "title": "Block title",
          "type": "strength",
          "estimatedMinutes": 15,
          "rounds": 1,
          "exercises": [
            {
              "name": "Exercise name",
              "prescription": "2 warmup sets + 3 x 5 @ 60 kg",
              "modality": "reps",
              "setMetricsStyle": "repsAndWeight",
              "plannedSets": [
                { "type": "warmup", "reps": 8, "weightKg": 20.0 },
                { "type": "working", "reps": 5, "weightKg": 60.0 }
              ],
              "restSeconds": 120,
              "notes": "Form cues"
            }
          ],
          "description": "Block description"
        }
      ]
    }
  ],
  "explanation": "Brief explanation of your overall reasoning"
}

Exercise rules:
- `modality` must be one of: reps, timed, hold, mobility, breath.
- `setMetricsStyle` must be one of: repsOnly, repsAndWeight, durationOnly, repsAndDuration.
- Use `repsAndWeight` for externally loaded exercises such as barbell, dumbbell, kettlebell, cable, machine, sled, or weighted bodyweight work.
- Use `repsOnly` for bodyweight or unloaded rep work such as pushups, bird dogs, dead bugs, squats, hinges, or crawls.
- Use `durationOnly` for timed holds, breathing, carries, rests, or intervals where the completed set is recorded only by time.
- Use `repsAndDuration` when each set has both a count and a duration, such as balance-on-one-foot sets, mobility reps with holds, or side-specific timed reps.
- Every exercise must include `prescription`: a concise, user-facing summary of the full prescription, including sets, reps/duration, load when relevant, and warmups when included.
- Every exercise must include `plannedSets`; use one object per set in performance order.
- Every planned set must include `type`: warmup or working.
- Use `weightKg` only when external load is relevant. Store all load in kilograms.
- Use `reps` for rep-based work.
- Use `durationSeconds` for timed, hold, mobility, or breath work.
- Include warmup sets when they matter for loaded strength work. Do not bury warmups in notes.''';
  }

  String buildUserPrompt(WorkoutContext context, String? feedback) {
    final buffer = StringBuffer();

    _appendPreferences(buffer, context);
    _appendGoalsPrompt(buffer, context);
    _appendInfluencesPrompt(buffer, context);
    _appendNotesPrompt(buffer, context);
    _appendRecentNotesPrompt(buffer, context);
    _appendExerciseLibrary(buffer, context);
    _appendCallToAction(buffer, feedback);

    return buffer.toString();
  }

  void _appendInfluencesPrompt(StringBuffer buffer, WorkoutContext context) {
    buffer.writeln('## Training Influences');
    if (context.influences.isEmpty) {
      buffer.writeln('No specific training influences selected.');
    } else {
      for (final influence in context.influences) {
        buffer.writeln('### ${influence.name}');
        buffer.writeln(influence.description);
        buffer.writeln('Key principles:');
        for (final principle in influence.principles) {
          buffer.writeln('- $principle');
        }
        buffer.writeln();
      }
    }
    buffer.writeln();
  }

  void _appendPreferences(StringBuffer buffer, WorkoutContext context) {
    final preferences = context.preferences;
    if (preferences == null || preferences.isEmpty) return;

    buffer.writeln('## Session Preferences');
    if (preferences.durationMinutes != null) {
      buffer.writeln(
        '- Target duration: ${preferences.durationMinutes} minutes',
      );
    }
    if (preferences.focusGoals.isNotEmpty) {
      final goalNames = preferences.focusGoals
          .map((goal) => goal.title)
          .join(', ');
      buffer.writeln('- Focus: $goalNames');
    }
    if (preferences.location != null) {
      buffer.writeln('- Location: ${preferences.location!.name}');
      if (preferences.location!.equipment.isNotEmpty) {
        buffer.writeln(
          '- Available equipment: ${preferences.location!.equipment}',
        );
      }
    }
    if (preferences.notes != null && preferences.notes!.isNotEmpty) {
      buffer.writeln('- Additional notes: ${preferences.notes}');
    }
    buffer.writeln();
  }

  void _appendExerciseLibrary(StringBuffer buffer, WorkoutContext context) {
    buffer.writeln('## My Exercise Library');
    if (context.knownExerciseNames.isEmpty) {
      buffer.writeln('No exercises yet.');
    } else {
      buffer.writeln(
        'Reuse these exact names when the same or equivalent exercise is intended:',
      );
      for (final name in context.knownExerciseNames) {
        buffer.writeln('- $name');
      }
    }
    buffer.writeln();
  }

  void _appendCallToAction(StringBuffer buffer, String? feedback) {
    buffer.writeln('## Request');
    if (feedback != null && feedback.isNotEmpty) {
      buffer.writeln(feedback);
    } else {
      buffer.writeln('What should I do today?');
    }
  }

  void _appendRecentNotesPrompt(StringBuffer buffer, WorkoutContext context) {
    buffer.writeln('## Recent Training (Last 7 Days)');
    if (context.recentSessions.isEmpty) {
      buffer.writeln('No recent sessions.');
    } else {
      for (final session in context.recentSessions) {
        final date = session.completedAt ?? session.startedAt;
        final dateText = '${date.month}/${date.day}';
        final duration = session.duration?.inMinutes ?? 0;
        buffer.writeln('- $dateText: ${duration}min session');
      }
    }
    buffer.writeln();
  }

  void _appendNotesPrompt(StringBuffer buffer, WorkoutContext context) {
    buffer.writeln('## Background Notes');
    if (context.backgroundNotes.isEmpty) {
      buffer.writeln('No specific constraints or preferences noted.');
    } else {
      for (final note in context.backgroundNotes) {
        buffer.writeln('- [${note.category.name}] ${note.content}');
      }
    }
    buffer.writeln();
  }

  void _appendGoalsPrompt(StringBuffer buffer, WorkoutContext context) {
    buffer.writeln('## My Goals');
    if (context.goals.isEmpty) {
      buffer.writeln('No specific goals set.');
    } else {
      for (final goal in context.goals) {
        final priority = goal.priority == 1 ? '(Primary)' : '(Secondary)';
        buffer.writeln('- ${goal.title} $priority: ${goal.description}');
      }
    }
    buffer.writeln();
  }
}
