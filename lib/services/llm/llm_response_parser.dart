import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/llm/llm_errors.dart';

const _log = ELogger('LlmResponseParser');

class LlmResponseParser {
  const LlmResponseParser();

  LlmWorkoutResponse parseWorkoutResponse(String body) {
    final content = _messageContent(body);
    _log.fine('Raw LLM content: $content');

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (error) {
      _log.error('Failed to decode JSON from LLM content: $error');
      _log.error('Content: $content');
      rethrow;
    }

    _log.log('Parsed ${(parsed['options'] as List).length} workout options');

    try {
      return LlmWorkoutResponse.fromJson(parsed);
    } catch (error, stack) {
      _log.error(
        'Error mapping JSON to LlmWorkoutResponse: $error',
        null,
        stack,
      );
      _log.error('Parsed JSON: $parsed');
      rethrow;
    }
  }

  List<ExerciseBenefit> parseBenefitsResponse(String body) {
    try {
      final content = _messageContent(body);
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final benefitsJson = parsed['benefits'] as List<dynamic>? ?? [];

      return benefitsJson
          .map(
            (benefitJson) =>
                ExerciseBenefit.fromJson(benefitJson as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      _log.error('Failed to parse benefits response: $error');
      return const [];
    }
  }

  TrainingInfluence parseInfluenceResponse(
    String body, {
    required String id,
    required String name,
  }) {
    final content = _messageContent(body);
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

  String parseLocationEquipmentResponse(String body) {
    final content = _messageContent(body);
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    return (parsed['equipment'] as String?) ?? '';
  }

  String _messageContent(String body) {
    final responseJson = jsonDecode(body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List<dynamic>;
    if (choices.isEmpty) throw LlmException('No response from model');

    final message = choices[0]['message'] as Map<String, dynamic>;
    return message['content'] as String;
  }
}
