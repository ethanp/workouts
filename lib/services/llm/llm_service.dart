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
import 'package:workouts/services/llm/llm_errors.dart';
import 'package:workouts/services/llm/llm_followup_prompt.dart';
import 'package:workouts/services/llm/llm_response_parser.dart';
import 'package:workouts/services/llm/llm_workout_prompt.dart';

part 'llm_service.g.dart';

const _log = ELogger('LlmService');

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

    final systemPrompt = const LlmWorkoutPromptBuilder().buildSystemPrompt();
    final userPrompt = const LlmWorkoutPromptBuilder().buildUserPrompt(
      context,
      userFeedback,
    );
    final List<Map<String, String>> inputPromptInfo = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];
    final http.Response response = await _feedToLlm(
      inputPromptInfo,
      httpClient,
    );

    if (response.statusCode != 200) {
      _log.error(
        'LLM Proxy error: ${response.statusCode}\n'
        'Headers: ${response.headers}\n'
        'Body: ${response.body}',
      );
    }

    return switch (response.statusCode) {
      200 => const LlmResponseParser().parseWorkoutResponse(response.body),
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

    final systemPrompt = const LlmWorkoutPromptBuilder().buildSystemPrompt();
    final userPrompt = const LlmWorkoutPromptBuilder().buildUserPrompt(
      context,
      userFeedback,
    );

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
        final response = const LlmResponseParser().parseWorkoutResponse(
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

    final followupPrompt = LlmFollowupPrompt.forQuestion(
      workoutResponse: workoutResponse,
      question: question,
    );

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
        {'role': 'system', 'content': followupPrompt.systemPrompt},
        {'role': 'user', 'content': followupPrompt.userPrompt},
      ],
      'max_tokens': 500,
      'stream': true,
    });

    return httpClient.send(request).asStream().asyncExpand((streamedResponse) {
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

    return const LlmResponseParser().parseBenefitsResponse(response.body);
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
    final hasExisting =
        (currentDescription?.isNotEmpty ?? false) ||
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

    return const LlmResponseParser().parseInfluenceResponse(
      response.body,
      id: id,
      name: name,
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

    return const LlmResponseParser().parseLocationEquipmentResponse(
      response.body,
    );
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
