import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/services/llm/llm_errors.dart';
import 'package:workouts/services/llm/llm_response_parser.dart';

void main() {
  const parser = LlmResponseParser();

  group('LlmResponseParser.parseWorkoutResponse', () {
    test('parses a valid chat envelope with workout content JSON', () {
      final response = parser.parseWorkoutResponse(
        _chatEnvelope({
          'options': [
            {
              'id': 'option-1',
              'title': 'Strength',
              'goal': 'Build strength',
              'rationale': 'Simple progression',
              'blocks': [
                {
                  'title': 'Main',
                  'type': 'strength',
                  'estimatedMinutes': 20,
                  'exercises': [
                    {
                      'name': 'Chest Press Machine',
                      'prescription': '1 x 8 @ 22.5 kg',
                      'modality': 'reps',
                      'plannedSets': [
                        {'reps': 8, 'weightKg': 22.5},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
          'explanation': 'Do the work.',
        }),
      );

      expect(response.options.single.title, 'Strength');
      expect(
        response.options.single.blocks.single.exercises.single.prescription,
        '1 x 8 @ 22.5 kg',
      );
      expect(
        response.options.single.blocks.single.exercises.single.plannedSets,
        hasLength(1),
      );
    });

    test('throws LlmException for malformed chat envelopes', () {
      expect(
        () => parser.parseWorkoutResponse(jsonEncode({'choices': []})),
        throwsA(isA<LlmException>()),
      );
      expect(
        () => parser.parseWorkoutResponse(jsonEncode({'choices': 'bad'})),
        throwsA(isA<LlmException>()),
      );
    });

    test('throws LlmException for invalid inner content JSON', () {
      expect(
        () => parser.parseWorkoutResponse(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{not json'},
              },
            ],
          }),
        ),
        throwsA(isA<LlmException>()),
      );
    });
  });

  group('LlmResponseParser.parseBenefitsResponse', () {
    test('parses benefits and filters malformed benefit rows', () {
      final benefits = parser.parseBenefitsResponse(
        _chatEnvelope({
          'benefits': [
            {
              'name': 'quad drive',
              'goalIds': ['goal-1', 4],
            },
            {
              'goalIds': ['missing-name'],
            },
          ],
        }),
      );

      expect(benefits, hasLength(1));
      expect(benefits.single.name, 'quad drive');
      expect(benefits.single.goalIds, ['goal-1']);
    });

    test('returns empty list for malformed response', () {
      expect(parser.parseBenefitsResponse('not json'), isEmpty);
    });
  });
}

String _chatEnvelope(Map<String, dynamic> content) {
  return jsonEncode({
    'choices': [
      {
        'message': {'content': jsonEncode(content)},
      },
    ],
  });
}
