import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/services/context_builder.dart';

part 'llm_service.g.dart';

final _log = Logger('LlmService');

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
    _log.info('Generating workout options...');
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
    final http.Response response = await feedToLlm(inputPromptInfo, httpClient);

    if (response.statusCode != 200) {
      _log.severe(
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

  Future<http.Response> feedToLlm(
    List<Map<String, String>> inputPromptInfo,
    http.Client httpClient,
  ) async {
    final url = '$proxyUrl/v1/chat/completions';
    _log.info('Calling LLM proxy at $url');

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
          .timeout(const Duration(seconds: 30));
      _log.info('LLM proxy responded: ${response.statusCode}');
      return response;
    } catch (e) {
      _log.severe('LLM proxy request failed: $e');
      rethrow;
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

Consider:
- Training influences and their principles (highest priority for exercise selection and cues)
- Goal alignment (prioritize primary goals)
- Recent history (avoid overtraining muscle groups)
- User constraints (injuries, time limits, equipment)
- Recovery needs

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

    appendGoalsPrompt(buffer, ctx);
    appendInfluencesPrompt(buffer, ctx);
    appendNotesPrompt(buffer, ctx);
    appendRecentNotesPrompt(buffer, ctx);
    appendCallToAction(buffer, feedback);

    return buffer.toString();
  }

  void appendInfluencesPrompt(StringBuffer buffer, WorkoutContext ctx) {
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

  void appendCallToAction(StringBuffer buffer, String? feedback) {
    buffer.writeln('## Request');
    if (feedback != null && feedback.isNotEmpty) {
      buffer.writeln(feedback);
    } else {
      buffer.writeln('What should I do today?');
    }
  }

  void appendRecentNotesPrompt(StringBuffer buffer, WorkoutContext ctx) {
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

  void appendNotesPrompt(StringBuffer buffer, WorkoutContext ctx) {
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

  void appendGoalsPrompt(StringBuffer buffer, WorkoutContext ctx) {
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
      _log.severe('Failed to decode JSON from LLM content: $e');
      _log.severe('Content: $content');
      rethrow;
    }

    _log.info('Parsed ${(parsed['options'] as List).length} workout options');

    try {
      return LlmWorkoutResponse.fromJson(parsed);
    } catch (e, stack) {
      _log.severe('Error mapping JSON to LlmWorkoutResponse: $e');
      _log.severe('Parsed JSON: $parsed');
      _log.severe(stack);
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
