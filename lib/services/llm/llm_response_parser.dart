import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/llm/llm_errors.dart';
import 'package:workouts/utils/json_parsing.dart';

const _log = ELogger('LlmResponseParser');

class LlmResponseParser {
  const LlmResponseParser();

  LlmWorkoutResponse parseWorkoutResponse(String body) {
    final content = _messageContent(body);
    _log.fine('Raw LLM content: $content');

    final parsed = _jsonObjectFromText(content, 'LLM workout content');

    final options = parsed['options'];
    final optionCount = options is List ? options.length : 0;
    _log.log('Parsed $optionCount workout options');

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
      final parsed = _jsonObjectFromText(content, 'LLM benefits content');
      final benefitsJson = parsed['benefits'] as List<dynamic>? ?? [];

      return benefitsJson
          .map(jsonMapFromObject)
          .whereType<Map<String, dynamic>>()
          .map(_tryExerciseBenefit)
          .whereType<ExerciseBenefit>()
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
    final parsed = _jsonObjectFromText(content, 'LLM influence content');

    final description = parsed['description'] as String? ?? '';

    return TrainingInfluence(
      id: id,
      name: name,
      description: description,
      principles: stringListFromObject(parsed['principles']),
      isActive: true,
    );
  }

  String parseLocationEquipmentResponse(String body) {
    final content = _messageContent(body);
    final parsed = _jsonObjectFromText(content, 'LLM equipment content');
    return (parsed['equipment'] as String?) ?? '';
  }

  String _messageContent(String body) {
    final responseJson = _jsonObjectFromText(body, 'LLM response envelope');
    final choices = responseJson['choices'];
    if (choices is! List<dynamic>) {
      throw LlmException('LLM response missing choices');
    }
    if (choices.isEmpty) throw LlmException('No response from model');

    final firstChoice = jsonMapFromObject(choices.first);
    final message = jsonMapFromObject(firstChoice?['message']);
    final content = message?['content'];
    if (content is! String) {
      throw LlmException('LLM response missing message content');
    }
    return content;
  }

  Map<String, dynamic> _jsonObjectFromText(String text, String label) {
    try {
      final decoded = jsonDecode(text);
      final jsonObject = jsonMapFromObject(decoded);
      if (jsonObject == null) {
        throw LlmException('$label must be a JSON object');
      }
      return jsonObject;
    } on LlmException {
      rethrow;
    } catch (error) {
      throw LlmException('Failed to decode $label: $error');
    }
  }

  ExerciseBenefit? _tryExerciseBenefit(Map<String, dynamic> benefitJson) {
    try {
      return ExerciseBenefit.fromJson(benefitJson);
    } catch (_) {
      return null;
    }
  }
}
