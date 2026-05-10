import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/exercise_benefit.dart';

void main() {
  group('ExerciseBenefit', () {
    test('roundtrips benefits through JSON string storage', () {
      final benefits = [
        const ExerciseBenefit(name: 'quad drive', goalIds: ['goal-1']),
        const ExerciseBenefit(name: 'posture', goalIds: []),
      ];

      final decodedBenefits = ExerciseBenefit.listFromJsonString(
        ExerciseBenefit.listToJsonString(benefits),
      );

      expect(decodedBenefits.map((benefit) => benefit.toJson()), [
        {
          'name': 'quad drive',
          'goalIds': ['goal-1'],
        },
        {'name': 'posture', 'goalIds': <String>[]},
      ]);
    });

    test('returns empty list for null empty or malformed JSON', () {
      expect(ExerciseBenefit.listFromJsonString(null), isEmpty);
      expect(ExerciseBenefit.listFromJsonString(''), isEmpty);
      expect(ExerciseBenefit.listFromJsonString('{not json'), isEmpty);
      expect(ExerciseBenefit.listFromJsonString('{"not":"a list"}'), isEmpty);
    });

    test('defaults missing goalIds and ignores malformed list elements', () {
      final benefitsJson = jsonEncode([
        {'name': 'bracing'},
        {
          'name': 'balance',
          'goalIds': ['goal-1', 7, null],
        },
        {
          'goalIds': ['missing-name'],
        },
        'not a benefit',
      ]);

      final decodedBenefits = ExerciseBenefit.listFromJsonString(benefitsJson);

      expect(decodedBenefits.map((benefit) => benefit.toJson()), [
        {'name': 'bracing', 'goalIds': <String>[]},
        {
          'name': 'balance',
          'goalIds': ['goal-1'],
        },
      ]);
    });
  });
}
