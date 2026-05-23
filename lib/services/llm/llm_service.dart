import 'package:ethan_utils/ethan_utils.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/services/sse_content_transformer.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/chat_message.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/exercise_replacement_suggestion.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/services/llm/llm_errors.dart';
import 'package:workouts/services/backend/service_urls.dart';
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

  /// Streams a chat completion against an arbitrary [systemPrompt] and
  /// running [history] of user/assistant turns. Caller owns the message list;
  /// each call sends `[system, ...history]` and yields token deltas as they
  /// arrive. Generic — the caller decides what the conversation is _about_.
  Stream<String> streamChat({
    required String systemPrompt,
    required List<ChatMessage> history,
    required http.Client httpClient,
    int maxTokens = 800,
  }) {
    final request =
        http.Request('POST', Uri.parse('$proxyUrl/v1/chat/completions'))
          ..headers.addAll({
            'Content-Type': 'application/json',
            'X-App-Name': appName,
            'X-App-Token': appSecret,
            'X-Client-ID': clientId,
          })
          ..body = jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              ...history.map((message) => message.toOpenAiJson()),
            ],
            'max_tokens': maxTokens,
            'stream': true,
          });

    return httpClient.send(request).asStream().asyncExpand((streamedResponse) {
      if (streamedResponse.statusCode == 429) {
        throw RateLimitedException();
      }
      if (streamedResponse.statusCode != 200) {
        throw LlmException(
          'Chat streaming failed: ${streamedResponse.statusCode}',
        );
      }
      return streamedResponse.stream.transform(SseContentTransformer());
    });
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

  /// Suggests up to 5 in-context substitutes for [originalExercise] when the
  /// user wants to swap it mid-session — typical reason: equipment is taken
  /// or the body part is fatigued.
  ///
  /// Suggestions may reference an existing library entry by id, or propose a
  /// brand-new movement that the caller will upsert into the library on
  /// confirm. The returned list never includes [originalExercise] itself or
  /// any exercise whose id appears in [excludeIds].
  Future<List<ExerciseReplacementSuggestion>> suggestExerciseReplacements({
    required WorkoutExercise originalExercise,
    String? availableEquipment,
    required List<FitnessGoal> activeGoals,
    required List<WorkoutExercise> libraryExercises,
    Set<String> excludeIds = const {},
  }) async {
    _log.log(
      'Suggesting replacements for "${originalExercise.name}"...',
    );

    final libraryById = {
      for (final exercise in libraryExercises) exercise.id: exercise,
    };
    final selectableLibrary = libraryExercises
        .where(
          (exercise) =>
              exercise.id != originalExercise.id &&
              !excludeIds.contains(exercise.id),
        )
        .toList();

    final systemPrompt = _replacementSuggestionsSystemPrompt();
    final userPrompt = _replacementSuggestionsUserPrompt(
      originalExercise: originalExercise,
      availableEquipment: availableEquipment,
      activeGoals: activeGoals,
      selectableLibrary: selectableLibrary,
    );

    final response = await _feedToLlm([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ], client);

    if (response.statusCode == 429) throw RateLimitedException();
    if (response.statusCode != 200) {
      throw LlmException(
        'Replacement suggestions failed: ${response.statusCode} ${response.body}',
      );
    }

    return const LlmResponseParser().parseReplacementSuggestionsResponse(
      response.body,
      libraryById: libraryById,
    );
  }

  String _replacementSuggestionsSystemPrompt() {
    return '''You are an expert strength and conditioning coach helping a user swap an exercise mid-workout.

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

  String _replacementSuggestionsUserPrompt({
    required WorkoutExercise originalExercise,
    required String? availableEquipment,
    required List<FitnessGoal> activeGoals,
    required List<WorkoutExercise> selectableLibrary,
  }) {
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

    final libraryJson = selectableLibrary
        .map(
          (exercise) => {
            'id': exercise.id,
            'name': exercise.name,
            'modality': exercise.modality.name,
            if (exercise.equipment != null && exercise.equipment!.isNotEmpty)
              'equipment': exercise.equipment,
            if (exercise.benefits.isNotEmpty)
              'benefits': exercise.benefits
                  .map((benefit) => benefit.name)
                  .toList(),
          },
        )
        .toList();

    final original = {
      'name': originalExercise.name,
      'modality': originalExercise.modality.name,
      'prescription': originalExercise.prescription,
      'set_metrics_style': originalExercise.setMetricsStyle.name,
      if (originalExercise.equipment != null &&
          originalExercise.equipment!.isNotEmpty)
        'equipment': originalExercise.equipment,
      if (originalExercise.benefits.isNotEmpty)
        'benefits': originalExercise.benefits
            .map((benefit) => benefit.name)
            .toList(),
      if (originalExercise.cues.isNotEmpty) 'cues': originalExercise.cues,
    };

    final buffer = StringBuffer()
      ..writeln('Original exercise to replace:')
      ..writeln(jsonEncode(original))
      ..writeln();
    if (availableEquipment != null && availableEquipment.trim().isNotEmpty) {
      buffer
        ..writeln('Available equipment in current location:')
        ..writeln(availableEquipment)
        ..writeln();
    }
    buffer
      ..writeln('Active user goals:')
      ..writeln(jsonEncode(goalsJson))
      ..writeln()
      ..writeln(
        'Existing library exercises (prefer these when a good match exists):',
      )
      ..writeln(jsonEncode(libraryJson));

    return buffer.toString();
  }
}

@riverpod
LlmService llmService(Ref ref) {
  final proxyUrl = ref.watch(llmProxyUrlProvider);
  final appName = dotenv.env['LLM_APP_NAME'] ?? 'workouts';
  final appSecret = dotenv.env['LLM_APP_SECRET'];

  if (appSecret == null || appSecret.isEmpty) {
    throw StateError('LLM_APP_SECRET not configured in .env');
  }

  final clientId = 'workouts-ios-client';

  return LlmService(
    proxyUrl: proxyUrl,
    appName: appName,
    appSecret: appSecret,
    clientId: clientId,
  );
}
