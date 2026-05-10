import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';

void main() {
  group('PlannedSet', () {
    test('roundtrips typed planned sets through JSON string storage', () {
      final plannedSets = [
        const PlannedSet(
          type: PlannedSetType.warmup,
          reps: 8,
          weight: Weight.kilograms(20),
        ),
        const PlannedSet(
          reps: 5,
          weight: Weight.kilograms(60),
          unitRemaining: 2,
        ),
        const PlannedSet(duration: Duration(seconds: 30)),
      ];

      final encodedPlannedSets = PlannedSet.listToJsonString(plannedSets);
      final decodedPlannedSets = PlannedSet.listFromJsonString(
        encodedPlannedSets,
      );

      expect(decodedPlannedSets, plannedSets);
    });

    test('keeps weightKg as the storage key for typed weights', () {
      const plannedSet = PlannedSet(reps: 5, weight: Weight.kilograms(60));

      expect(plannedSet.toJson()['weightKg'], 60);
      expect(
        PlannedSet.fromJson({'reps': 5, 'weightKg': 60}).weight,
        const Weight.kilograms(60),
      );
    });

    test('decodes double-encoded planned set strings from synced rows', () {
      final plannedSets = [
        const PlannedSet(
          type: PlannedSetType.warmup,
          reps: 8,
          weight: Weight.kilograms(20),
        ),
        const PlannedSet(reps: 5, weight: Weight.kilograms(60)),
      ];

      final encodedPlannedSets = PlannedSet.listToJsonString(plannedSets);
      final doubleEncodedPlannedSets = jsonEncode(encodedPlannedSets);

      expect(
        PlannedSet.listFromJsonString(doubleEncodedPlannedSets),
        plannedSets,
      );
    });

    test('throws for malformed planned set JSON instead of inventing sets', () {
      expect(
        () => PlannedSet.listFromJsonString('{not json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PlannedSet.listFromJsonString('"not a list"'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PlannedSet.listFromJsonString(jsonEncode(['not a map'])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WorkoutExercise prescriptions', () {
    test('uses planned set count and label when planned sets exist', () {
      final exercise = WorkoutExercise(
        id: 'squat',
        name: 'Back Squat',
        modality: ExerciseModality.reps,
        prescription: 'legacy',
        targetSets: 1,
        plannedSets: const [
          PlannedSet(
            type: PlannedSetType.warmup,
            reps: 8,
            weight: Weight.kilograms(20),
          ),
          PlannedSet(
            type: PlannedSetType.warmup,
            reps: 5,
            weight: Weight.kilograms(40),
          ),
          PlannedSet(reps: 5, weight: Weight.kilograms(60)),
          PlannedSet(reps: 5, weight: Weight.kilograms(60)),
          PlannedSet(reps: 5, weight: Weight.kilograms(60)),
        ],
      );

      expect(exercise.effectiveTargetSets, 5);
      expect(exercise.warmupSetCount, 2);
      expect(exercise.workingSetCount, 3);
      expect(exercise.prescriptionLabel, '2 warmup + 3 x 5 @ 132.3lb');
    });

    test('keeps kettlebell prescription labels in kilograms', () {
      final exercise = WorkoutExercise(
        id: 'swing',
        name: 'Kettlebell Swing',
        modality: ExerciseModality.reps,
        prescription: 'legacy',
        plannedSets: const [
          PlannedSet(reps: 10, weight: Weight.kilograms(20)),
          PlannedSet(reps: 10, weight: Weight.kilograms(20)),
        ],
      );

      expect(exercise.prescriptionLabel, '2 x 10 @ 20kg');
    });
  });
}
