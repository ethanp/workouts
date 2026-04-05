import 'package:ethan_utils/ethan_utils.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/services/sse_content_transformer.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/context_builder.dart';

part 'llm_service.g.dart';

const _log = ELogger('LlmService');

class RateLimitedException implements Exception {
  final Duration retryAfter;

  RateLimitedException({this.retryAfter = const Duration(minutes: 5)});

  @override
  String toString() =>
      'Rate limited. Try again in ${retryAfter.inMinutes} minutes.';
}

class LlmException implements Exception {
  final String message;

  LlmException(this.message);

  @override
  String toString() => message;
}

class LlmService {
  final String proxyUrl;
  final String appName;
  final String appSecret;
  final String clientId;
  final http.Client client;

  LlmService({
    required this.proxyUrl,
    required this.appName,
    required this.appSecret,
    required this.clientId,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<LlmWorkoutResponse> generateWorkoutOptions({
    required WorkoutContext context,
    String? userFeedback,
    http.Client? client,
  }) async {
    final httpClient = client ?? this.client;
    _log.log('Generating workout options...');
    _log.fine(
      'Context: ${context.goals.length} goals, '
      '${context.backgroundNotes.length} notes, '
      '${context.recentSessions.length} recent sessions, '
      '${context.influences.length} influences',
    );

    final String systemPrompt = _buildSystemPrompt();
    final String userPrompt = _buildUserPrompt(context, userFeedback);
    final List<Map<String, String>> inputPromptInfo = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];
    final http.Response response = await _feedToLlm(inputPromptInfo, httpClient);

    if (response.statusCode != 200) {
      _log.error(
        'LLM Proxy error: ${response.statusCode}\n'
        'Headers: ${response.headers}\n'
        'Body: ${response.body}',
      );
    }

    return switch (response.statusCode) {
      200 => _parseResponse(response.body),
      429 => throw RateLimitedException(),
      401 => throw LlmException('Authentication failed ${response.body}'),
      _ => throw LlmException(
        'Request failed: ${response.statusCode} ${response.body}',
      ),
    };
  }

  /// Streams workout generation, returning token deltas for live display
  /// and a future that resolves to the parsed response once complete.
  ({Stream<String> tokens, Future<LlmWorkoutResponse> parsed})
      streamWorkoutOptions({
    required WorkoutContext context,
    String? userFeedback,
    required http.Client httpClient,
  }) {
    _log.log('Streaming workout options...');

    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(context, userFeedback);

    final url = Uri.parse('$proxyUrl/v1/chat/completions');
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'X-App-Name': appName,
      'X-App-Token': appSecret,
      'X-Client-ID': clientId,
    });
    request.body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'response_format': {'type': 'json_object'},
      'max_tokens': 2000,
      'stream': true,
    });

    final accumulated = StringBuffer();
    final completer = Completer<LlmWorkoutResponse>();

    final tokenStream = httpClient
        .send(request)
        .asStream()
        .asyncExpand((streamedResponse) {
          if (streamedResponse.statusCode == 429) {
            throw RateLimitedException();
          }
          if (streamedResponse.statusCode != 200) {
            throw LlmException(
              'Streaming failed: ${streamedResponse.statusCode}',
            );
          }
          return streamedResponse.stream.transform(SseContentTransformer());
        })
        .map((delta) {
          accumulated.write(delta);
          return delta;
        })
        .handleError((Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        });

    final broadcastTokens = tokenStream.asBroadcastStream(
      onCancel: (subscription) => subscription.cancel(),
    );

    broadcastTokens.drain<void>().then((_) {
      if (completer.isCompleted) return;
      try {
        final response = _parseResponse(
          '{"choices":[{"message":{"content":${jsonEncode(accumulated.toString())}}}]}',
        );
        _log.log('Streamed ${response.options.length} workout options');
        completer.complete(response);
      } catch (error) {
        completer.completeError(error);
      }
    });

    return (tokens: broadcastTokens, parsed: completer.future);
  }

  Stream<String> streamFollowup({
    required LlmWorkoutResponse workoutResponse,
    required String question,
    required http.Client httpClient,
  }) {
    _log.log('Streaming followup Q&A...');

    final workoutSummary = StringBuffer();
    for (final option in workoutResponse.options) {
      workoutSummary.writeln('## ${option.title} (${option.goal})');
      workoutSummary.writeln(option.rationale);
      for (final block in option.blocks) {
        workoutSummary.writeln(
            '- ${block.title} (${block.estimatedMinutes}min): '
            '${block.exercises.map((exercise) => exercise.name).join(', ')}');
      }
      workoutSummary.writeln();
    }

    const systemPrompt =
        'You are a personal fitness coach. The user just received AI-generated '
        'workout options. Answer their question conversationally and concisely. '
        'Do not use markdown formatting. Keep answers under 200 words.';

    final userPrompt = 'Here are the workout options I was given:\n\n'
        '$workoutSummary\n'
        'My question: $question';

    final url = Uri.parse('$proxyUrl/v1/chat/completions');
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'X-App-Name': appName,
      'X-App-Token': appSecret,
      'X-Client-ID': clientId,
    });
    request.body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'max_tokens': 500,
      'stream': true,
    });

    return httpClient
        .send(request)
        .asStream()
        .asyncExpand((streamedResponse) {
      if (streamedResponse.statusCode == 429) {
        throw RateLimitedException();
      }
      if (streamedResponse.statusCode != 200) {
        throw LlmException(
          'Followup streaming failed: ${streamedResponse.statusCode}',
        );
      }
      return streamedResponse.stream.transform(SseContentTransformer());
    });
  }

  Future<http.Response> _feedToLlm(
    List<Map<String, String>> inputPromptInfo,
    http.Client httpClient,
  ) async {
    final url = '$proxyUrl/v1/chat/completions';
    _log.log('Calling LLM proxy at $url');

    try {
      final response = await httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Name': appName,
              'X-App-Token': appSecret,
              'X-Client-ID': clientId,
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': inputPromptInfo,
              'response_format': {'type': 'json_object'},
              'max_tokens': 2000,
            }),
          )
          .timeout(const Duration(seconds: 60));
      _log.log('LLM proxy responded: ${response.statusCode}');
      return response;
    } catch (e) {
      _log.error('LLM proxy request failed: $e');
      rethrow;
    }
  }

  /// Generates a list of physiological benefits for an exercise, with optional
  /// links to the user's fitness goals by ID.
  ///
  /// Returns an empty list if the model returns no valid benefits.
  Future<List<ExerciseBenefit>> generateExerciseBenefits({
    required String exerciseName,
    String? exerciseNotes,
    required List<FitnessGoal> activeGoals,
  }) async {
    _log.log('Generating benefits for "$exerciseName"...');

    final goalsJson = activeGoals
        .map(
          (goal) => {
            'id': goal.id,
            'title': goal.title,
            'category': goal.category.name,
            if (goal.description.isNotEmpty) 'description': goal.description,
          },
        )
        .toList();

    final systemPrompt = '''You are an expert exercise physiologist.
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

    final userPrompt = StringBuffer()
      ..writeln('Exercise: $exerciseName')
      ..writeln(exerciseNotes != null ? 'Notes: $exerciseNotes' : '')
      ..writeln()
      ..writeln('User goals:')
      ..writeln(jsonEncode(goalsJson));

    final response = await _feedToLlm([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt.toString()},
    ], client);

    if (response.statusCode != 200) {
      throw LlmException(
        'Benefit generation failed: ${response.statusCode} ${response.body}',
      );
    }

    return _parseBenefitsResponse(response.body);
  }

  /// Given a coach/influencer/program name, generates a description and
  /// key training principles using the LLM.
  /// Given a coach/influencer/program name, generates or revises a description
  /// and key training principles using the LLM.
  ///
  /// When [currentDescription] and [currentPrinciples] are provided, the LLM
  /// revises and improves the existing content rather than generating from
  /// scratch.
  Future<TrainingInfluence> generateInfluenceDetails({
    required String id,
    required String name,
    String? currentDescription,
    List<String>? currentPrinciples,
  }) async {
    final hasExisting = (currentDescription?.isNotEmpty ?? false) ||
        (currentPrinciples?.isNotEmpty ?? false);
    _log.log(
      hasExisting
          ? 'Revising influence details for "$name"...'
          : 'Generating influence details for "$name"...',
    );

    final systemPrompt = hasExisting
        ? '''You are an expert in longevity, posture, physical therapy, mobility, occupational therapy, strength, conditioning, and movement coaching.
The user has a training influence entry with a description and principles that they have drafted or edited. Revise and improve the content:
- Refine the description for clarity and accuracy (keep it one sentence)
- Improve, expand, or correct the principles (aim for 4-6 total)
- Preserve the user's intent — enhance, don't replace wholesale

Each principle should be a short sentence: a concise label, then a dash, then a brief explanation.

Respond with valid JSON only, no markdown. Structure:
{
  "description": "string",
  "principles": ["string", ...]
}'''
        : '''You are an expert in longevity, posture, physical therapy, mobility, occupational therapy, strength, conditioning, and movement coaching.
Given a coach, program, book, or training philosophy name, provide:
1. A concise one-sentence description of who/what they are
2. 4-6 key training principles they are known for

Each principle should be a short sentence: a concise label, then a dash, then a brief explanation.

Respond with valid JSON only, no markdown. Structure:
{
  "description": "string",
  "principles": ["string", ...]
}''';

    final userPrompt = StringBuffer('Name: $name');
    if (hasExisting) {
      if (currentDescription != null && currentDescription.isNotEmpty) {
        userPrompt.writeln('\n\nCurrent description: $currentDescription');
      }
      if (currentPrinciples != null && currentPrinciples.isNotEmpty) {
        userPrompt.writeln('\nCurrent principles:');
        for (final principle in currentPrinciples) {
          userPrompt.writeln('- $principle');
        }
      }
    }

    final response = await _feedToLlm([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt.toString()},
    ], client);

    if (response.statusCode == 429) throw RateLimitedException();
    if (response.statusCode != 200) {
      throw LlmException(
        'Influence generation failed: ${response.statusCode} ${response.body}',
      );
    }

    return _parseInfluenceResponse(response.body, id: id, name: name);
  }

  TrainingInfluence _parseInfluenceResponse(
    String body, {
    required String id,
    required String name,
  }) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      throw LlmException('No response from model');
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String;
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    final description = parsed['description'] as String? ?? '';
    final principlesJson = parsed['principles'] as List<dynamic>? ?? [];

    return TrainingInfluence(
      id: id,
      name: name,
      description: description,
      principles: principlesJson.cast<String>(),
      isActive: true,
    );
  }

  /// Given a training location name (e.g. "Home Gym"), generates a
  /// comma-separated equipment list. When [currentEquipment] is provided,
  /// the LLM revises and improves the existing list.
  Future<String> generateLocationEquipment({
    required String locationName,
    String? currentEquipment,
  }) async {
    final hasExisting = currentEquipment != null && currentEquipment.isNotEmpty;
    _log.log(
      hasExisting
          ? 'Revising equipment for "$locationName"...'
          : 'Generating equipment for "$locationName"...',
    );

    final systemPrompt = hasExisting
        ? '''You are a fitness equipment expert. The user has a training location with an equipment list they have drafted. Revise and improve it:
- Add commonly available items they may have missed
- Keep the format as a comma-separated list
- Preserve the user's existing items unless clearly wrong

Respond with valid JSON only, no markdown. Structure:
{ "equipment": "comma-separated equipment list" }'''
        : '''You are a fitness equipment expert. Given a training location name, suggest what equipment is typically available there.

Respond with valid JSON only, no markdown. Structure:
{ "equipment": "comma-separated equipment list" }''';

    final userPrompt = StringBuffer('Location: $locationName');
    if (hasExisting) {
      userPrompt.write('\nCurrent equipment: $currentEquipment');
    }

    final response = await _feedToLlm([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt.toString()},
    ], client);

    if (response.statusCode == 429) throw RateLimitedException();
    if (response.statusCode != 200) {
      throw LlmException(
        'Equipment generation failed: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>;
    if (choices.isEmpty) throw LlmException('No response from model');

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String;
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    return (parsed['equipment'] as String?) ?? '';
  }

  List<ExerciseBenefit> _parseBenefitsResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      if (choices.isEmpty) return const [];

      final message = choices[0]['message'] as Map<String, dynamic>;
      final content = message['content'] as String;

      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final benefitsJson = parsed['benefits'] as List<dynamic>? ?? [];

      return benefitsJson
          .map((item) => ExerciseBenefit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      _log.error('Failed to parse benefits response: $error');
      return const [];
    }
  }

  String _buildSystemPrompt() {
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
- List of exercises with sets/reps/duration as appropriate
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
            { "name": "Exercise name", "sets": "3", "reps": "10", "notes": "Form cues" }
          ],
          "description": "Block description"
        }
      ]
    }
  ],
  "explanation": "Brief explanation of your overall reasoning"
}''';
  }

  String _buildUserPrompt(WorkoutContext ctx, String? feedback) {
    final buffer = StringBuffer();

    _appendPreferences(buffer, ctx);
    _appendGoalsPrompt(buffer, ctx);
    _appendInfluencesPrompt(buffer, ctx);
    _appendNotesPrompt(buffer, ctx);
    _appendRecentNotesPrompt(buffer, ctx);
    _appendExerciseLibrary(buffer, ctx);
    _appendCallToAction(buffer, feedback);

    return buffer.toString();
  }

  void _appendInfluencesPrompt(StringBuffer buffer, WorkoutContext ctx) {
    buffer.writeln('## Training Influences');
    if (ctx.influences.isEmpty) {
      buffer.writeln('No specific training influences selected.');
    } else {
      for (final influence in ctx.influences) {
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

  void _appendPreferences(StringBuffer buffer, WorkoutContext ctx) {
    final prefs = ctx.preferences;
    if (prefs == null || prefs.isEmpty) return;

    buffer.writeln('## Session Preferences');
    if (prefs.durationMinutes != null) {
      buffer.writeln('- Target duration: ${prefs.durationMinutes} minutes');
    }
    if (prefs.focusGoals.isNotEmpty) {
      final goalNames = prefs.focusGoals.map((goal) => goal.title).join(', ');
      buffer.writeln('- Focus: $goalNames');
    }
    if (prefs.location != null) {
      buffer.writeln('- Location: ${prefs.location!.name}');
      if (prefs.location!.equipment.isNotEmpty) {
        buffer.writeln(
          '- Available equipment: ${prefs.location!.equipment}',
        );
      }
    }
    if (prefs.notes != null && prefs.notes!.isNotEmpty) {
      buffer.writeln('- Additional notes: ${prefs.notes}');
    }
    buffer.writeln();
  }

  void _appendExerciseLibrary(StringBuffer buffer, WorkoutContext ctx) {
    buffer.writeln('## My Exercise Library');
    if (ctx.knownExerciseNames.isEmpty) {
      buffer.writeln('No exercises yet.');
    } else {
      buffer.writeln(
        'Reuse these exact names when the same or equivalent exercise is intended:',
      );
      for (final name in ctx.knownExerciseNames) {
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

  void _appendRecentNotesPrompt(StringBuffer buffer, WorkoutContext ctx) {
    buffer.writeln('## Recent Training (Last 7 Days)');
    if (ctx.recentSessions.isEmpty) {
      buffer.writeln('No recent sessions.');
    } else {
      for (final session in ctx.recentSessions) {
        final date = session.completedAt ?? session.startedAt;
        final dateStr = '${date.month}/${date.day}';
        final duration = session.duration?.inMinutes ?? 0;
        buffer.writeln('- $dateStr: ${duration}min session');
      }
    }
    buffer.writeln();
  }

  void _appendNotesPrompt(StringBuffer buffer, WorkoutContext ctx) {
    buffer.writeln('## Background Notes');
    if (ctx.backgroundNotes.isEmpty) {
      buffer.writeln('No specific constraints or preferences noted.');
    } else {
      for (final note in ctx.backgroundNotes) {
        buffer.writeln('- [${note.category.name}] ${note.content}');
      }
    }
    buffer.writeln();
  }

  void _appendGoalsPrompt(StringBuffer buffer, WorkoutContext ctx) {
    buffer.writeln('## My Goals');
    if (ctx.goals.isEmpty) {
      buffer.writeln('No specific goals set.');
    } else {
      for (final goal in ctx.goals) {
        final priority = goal.priority == 1 ? '(Primary)' : '(Secondary)';
        buffer.writeln('- ${goal.title} $priority: ${goal.description}');
      }
    }
    buffer.writeln();
  }

  LlmWorkoutResponse _parseResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      throw LlmException('No response from model');
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String;
    _log.fine('Raw LLM content: $content');

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      _log.error('Failed to decode JSON from LLM content: $e');
      _log.error('Content: $content');
      rethrow;
    }

    _log.log('Parsed ${(parsed['options'] as List).length} workout options');

    try {
      return LlmWorkoutResponse.fromJson(parsed);
    } catch (e, stack) {
      _log.error('Error mapping JSON to LlmWorkoutResponse: $e', null, stack);
      _log.error('Parsed JSON: $parsed');
      rethrow;
    }
  }
}

@riverpod
LlmService llmService(Ref ref) {
  final proxyUrl = dotenv.env['LLM_PROXY_URL'];
  final appName = dotenv.env['LLM_APP_NAME'] ?? 'workouts';
  final appSecret = dotenv.env['LLM_APP_SECRET'];

  if (proxyUrl == null || proxyUrl.isEmpty) {
    throw StateError('LLM_PROXY_URL not configured in .env');
  }
  if (appSecret == null || appSecret.isEmpty) {
    throw StateError('LLM_APP_SECRET not configured in .env');
  }

  // Use a stable client ID - for now just use a fixed ID per app
  // In production, you might want to use device_info or stored UUID
  final clientId = 'workouts-ios-client';

  return LlmService(
    proxyUrl: proxyUrl,
    appName: appName,
    appSecret: appSecret,
    clientId: clientId,
  );
}
