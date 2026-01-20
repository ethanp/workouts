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
  }) async {
    _log.info('Generating workout options...');
    _log.fine(
      'Context: ${context.goals.length} goals, '
      '${context.backgroundNotes.length} notes, '
      '${context.recentSessions.length} recent sessions',
    );

    final String systemPrompt = _buildSystemPrompt();
    final String userPrompt = _buildUserPrompt(context, userFeedback);
    final List<Map<String, String>> inputPromptInfo = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];
    final http.Response response = await feedToLlm(inputPromptInfo);

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
  ) async {
    final url = '$proxyUrl/v1/chat/completions';
    _log.info('Calling LLM proxy at $url');

    try {
      final response = await client
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
              'max_tokens': 1000,
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
    return '''You are a personal fitness coach. Based on the user's goals, constraints, and recent training history, suggest 2-3 workout options for today.

For each option provide:
1. A descriptive title
2. Estimated duration in minutes
3. A brief rationale explaining why this fits today
4. A list of exercises with sets/reps/duration as appropriate

Consider:
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
      "estimatedMinutes": 35,
      "rationale": "Why this workout fits today",
      "exercises": [
        { "name": "Exercise name", "sets": "3", "reps": "10" }
      ]
    }
  ],
  "explanation": "Brief explanation of your overall reasoning"
}''';
  }

  String _buildUserPrompt(WorkoutContext ctx, String? feedback) {
    final buffer = StringBuffer();

    appendGoalsPrompt(buffer, ctx);
    appendNotesPrompt(buffer, ctx);
    appendRecentNotesPrompt(buffer, ctx);
    appendCallToAction(buffer, feedback);

    return buffer.toString();
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
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    _log.info('Parsed ${(parsed['options'] as List).length} workout options');

    return LlmWorkoutResponse.fromJson(parsed);
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
