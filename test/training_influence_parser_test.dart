import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/training_influence.dart';

void main() {
  group('TrainingInfluence.fromRow', () {
    test('parses principles and active flag from database row', () {
      final influence = TrainingInfluence.fromRow({
        'id': 'coach',
        'name': 'Coach',
        'description': 'Method',
        'principles': '["brace", "breathe"]',
        'is_active': 1,
      });

      expect(influence.principles, ['brace', 'breathe']);
      expect(influence.isActive, isTrue);
    });

    test('uses empty principles for malformed database text', () {
      final influence = TrainingInfluence.fromRow({
        'id': 'coach',
        'name': 'Coach',
        'principles': '{not json',
        'is_active': 0,
      });

      expect(influence.principles, isEmpty);
      expect(influence.isActive, isFalse);
    });
  });
}
