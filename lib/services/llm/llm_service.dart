import 'package:ethan_utils/ethan_utils.dart';

import 'dart:convert';

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
import 'package:workouts/services/llm/llm_exercise_benefits_prompt.dart';
import 'package:workouts/services/llm/llm_followup_prompt.dart';
import 'package:workouts/services/llm/llm_influence_prompt.dart';
import 'package:workouts/services/llm/llm_location_equipment_prompt.dart';
import 'package:workouts/services/llm/llm_replacement_prompt.dart';
import 'package:workouts/services/llm/llm_response_parser.dart';
import 'package:workouts/services/llm/llm_workout_prompt.dart';
import 'package:workouts/services/llm/llm_workout_stream.dart';

part 'llm_service.g.dart';

const _log = ELogger('LlmService');

class LlmService({
  required final String proxyUrl,
  required final String appName,
  required final String appSecret,
  required final String clientId,
  http.Client? client,
}) {
  final http.Client client = client ?? http.Client();

  Map<String, String> get _proxyHeaders => {
    'Content-Type': 'application/json',
    'X-App-Name': appName,
    'X-App-Token': appSecret,
    'X-Client-ID': clientId,
  };

  Future<LlmWorkoutResponse> generateWorkoutOptions({
    required WorkoutContext context,
    String? userFeedback,
    http.Client? client,
  }) async {
    _log.log('Generating workout options...');
    _log.fine(
      'Context: ${context.goals.length} goals, '
      '${context.backgroundNotes.length} notes, '
      '${context.recentSessions.length} recent sessions, '
      '${context.influences.length} influences',
    );

    final prompt = const LlmWorkoutPromptBuilder();
    final body = await _feedToLlm(
      systemPrompt: prompt.buildSystemPrompt(),
      userPrompt: prompt.buildUserPrompt(context, userFeedback),
      httpClient: client,
      failedLabel: 'Request failed',
    );
    return const LlmResponseParser().parseWorkoutResponse(body);
  }

  LlmWorkoutStream streamWorkoutOptions({
    required WorkoutContext context,
    String? userFeedback,
    required http.Client httpClient,
  }) {
    _log.log('Streaming workout options...');
    final prompt = const LlmWorkoutPromptBuilder();
    return LlmWorkoutStream.fromTokenDeltas(
      _streamFromLlm(
        messages: [
          {'role': 'system', 'content': prompt.buildSystemPrompt()},
          {
            'role': 'user',
            'content': prompt.buildUserPrompt(context, userFeedback),
          },
        ],
        httpClient: httpClient,
        maxTokens: 2000,
        jsonObject: true,
        failedLabel: 'Streaming failed',
      ),
    );
  }

  Stream<String> streamChat({
    required String systemPrompt,
    required List<ChatMessage> history,
    required http.Client httpClient,
    int maxTokens = 800,
  }) {
    return _streamFromLlm(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        ...history.map((message) => message.toOpenAiJson()),
      ],
      httpClient: httpClient,
      maxTokens: maxTokens,
      failedLabel: 'Chat streaming failed',
    );
  }

  Stream<String> streamFollowup({
    required LlmWorkoutResponse workoutResponse,
    required String question,
    required http.Client httpClient,
  }) {
    _log.log('Streaming followup Q&A...');
    final prompt = LlmFollowupPrompt.forQuestion(
      workoutResponse: workoutResponse,
      question: question,
    );
    return _streamFromLlm(
      messages: [
        {'role': 'system', 'content': prompt.systemPrompt},
        {'role': 'user', 'content': prompt.userPrompt},
      ],
      httpClient: httpClient,
      maxTokens: 500,
      failedLabel: 'Followup streaming failed',
    );
  }

  Future<List<ExerciseBenefit>> generateExerciseBenefits({
    required String exerciseName,
    String? exerciseNotes,
    required List<FitnessGoal> activeGoals,
  }) async {
    _log.log('Generating benefits for "$exerciseName"...');
    final prompt = LlmExerciseBenefitsPrompt.forExercise(
      exerciseName: exerciseName,
      exerciseNotes: exerciseNotes,
      activeGoals: activeGoals,
    );
    final body = await _feedToLlm(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
      failedLabel: 'Benefit generation failed',
    );
    return const LlmResponseParser().parseBenefitsResponse(body);
  }

  Future<TrainingInfluence> generateInfluenceDetails({
    required String id,
    required String name,
    String? currentDescription,
    List<String>? currentPrinciples,
  }) async {
    final prompt = LlmInfluencePrompt.forName(
      name: name,
      currentDescription: currentDescription,
      currentPrinciples: currentPrinciples,
    );
    _log.log(
      prompt.isRevision
          ? 'Revising influence details for "$name"...'
          : 'Generating influence details for "$name"...',
    );
    final body = await _feedToLlm(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
      failedLabel: 'Influence generation failed',
    );
    return const LlmResponseParser().parseInfluenceResponse(
      body,
      id: id,
      name: name,
    );
  }

  Future<String> generateLocationEquipment({
    required String locationName,
    String? currentEquipment,
  }) async {
    final prompt = LlmLocationEquipmentPrompt.forLocation(
      locationName: locationName,
      currentEquipment: currentEquipment,
    );
    _log.log(
      prompt.isRevision
          ? 'Revising equipment for "$locationName"...'
          : 'Generating equipment for "$locationName"...',
    );
    final body = await _feedToLlm(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
      failedLabel: 'Equipment generation failed',
    );
    return const LlmResponseParser().parseLocationEquipmentResponse(body);
  }

  Future<List<ExerciseReplacementSuggestion>> suggestExerciseReplacements({
    required WorkoutExercise originalExercise,
    String? availableEquipment,
    required List<FitnessGoal> activeGoals,
    required List<WorkoutExercise> libraryExercises,
    Set<String> excludeIds = const {},
  }) async {
    _log.log('Suggesting replacements for "${originalExercise.name}"...');
    final prompt = LlmReplacementPrompt.forExercise(
      originalExercise: originalExercise,
      availableEquipment: availableEquipment,
      activeGoals: activeGoals,
      libraryExercises: libraryExercises,
      excludeIds: excludeIds,
    );
    final body = await _feedToLlm(
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
      failedLabel: 'Replacement suggestions failed',
    );
    return const LlmResponseParser().parseReplacementSuggestionsResponse(
      body,
      libraryById: {
        for (final exercise in libraryExercises) exercise.id: exercise,
      },
    );
  }

  Future<String> _feedToLlm({
    required String systemPrompt,
    required String userPrompt,
    http.Client? httpClient,
    required String failedLabel,
  }) async {
    final url = '$proxyUrl/v1/chat/completions';
    _log.log('Calling LLM proxy at $url');

    final http.Response response;
    try {
      response = await (httpClient ?? client)
          .post(
            Uri.parse(url),
            headers: _proxyHeaders,
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'response_format': {'type': 'json_object'},
              'max_tokens': 2000,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (error) {
      _log.error('LLM proxy request failed: $error');
      rethrow;
    }

    _log.log('LLM proxy responded: ${response.statusCode}');
    _requireOkStatus(
      response.statusCode,
      body: response.body,
      failedLabel: failedLabel,
    );
    return response.body;
  }

  Stream<String> _streamFromLlm({
    required List<Map<String, String>> messages,
    required http.Client httpClient,
    required int maxTokens,
    required String failedLabel,
    bool jsonObject = false,
  }) {
    final request =
        http.Request('POST', Uri.parse('$proxyUrl/v1/chat/completions'))
          ..headers.addAll(_proxyHeaders)
          ..body = jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': messages,
            if (jsonObject) 'response_format': {'type': 'json_object'},
            'max_tokens': maxTokens,
            'stream': true,
          });

    return httpClient.send(request).asStream().asyncExpand((streamedResponse) {
      _requireOkStatus(streamedResponse.statusCode, failedLabel: failedLabel);
      return streamedResponse.stream.transform(SseContentTransformer());
    });
  }

  void _requireOkStatus(
    int statusCode, {
    String body = '',
    required String failedLabel,
  }) {
    if (statusCode == 200) return;
    _log.error(
      'LLM Proxy error: $statusCode'
      '${body.isEmpty ? '' : '\nBody: $body'}',
    );
    throw switch (statusCode) {
      429 => RateLimitedException(),
      401 => LlmException(
        body.isEmpty ? 'Authentication failed' : 'Authentication failed $body',
      ),
      _ => LlmException(
        body.isEmpty
            ? '$failedLabel: $statusCode'
            : '$failedLabel: $statusCode $body',
      ),
    };
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

  return LlmService(
    proxyUrl: proxyUrl,
    appName: appName,
    appSecret: appSecret,
    clientId: 'workouts-ios-client',
  );
}
