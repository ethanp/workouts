import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:workouts/models/workout_exercise.dart';

void main() {
  group('PlannedSet', () {
    test('roundtrips typed planned sets through JSON string storage', () {
      final plannedSets = [
        const PlannedSet(type: PlannedSetType.warmup, reps: 8, weightKg: 20),
        const PlannedSet(reps: 5, weightKg: 60, unitRemaining: 2),
        const PlannedSet(duration: Duration(seconds: 30)),
      ];

      final encodedPlannedSets = PlannedSet.listToJsonString(plannedSets);
      final decodedPlannedSets = PlannedSet.listFromJsonString(
        encodedPlannedSets,
      );

      expect(decodedPlannedSets, plannedSets);
    });

    test('decodes double-encoded planned set strings from synced rows', () {
      final plannedSets = [
        const PlannedSet(type: PlannedSetType.warmup, reps: 8, weightKg: 20),
        const PlannedSet(reps: 5, weightKg: 60),
      ];

      final encodedPlannedSets = PlannedSet.listToJsonString(plannedSets);
      final doubleEncodedPlannedSets = jsonEncode(encodedPlannedSets);

      expect(
        PlannedSet.listFromJsonString(doubleEncodedPlannedSets),
        plannedSets,
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
          PlannedSet(type: PlannedSetType.warmup, reps: 8, weightKg: 20),
          PlannedSet(type: PlannedSetType.warmup, reps: 5, weightKg: 40),
          PlannedSet(reps: 5, weightKg: 60),
          PlannedSet(reps: 5, weightKg: 60),
          PlannedSet(reps: 5, weightKg: 60),
        ],
      );

      expect(exercise.effectiveTargetSets, 5);
      expect(exercise.warmupSetCount, 2);
      expect(exercise.workingSetCount, 3);
      expect(exercise.prescriptionLabel, '2 warmup + 3 x 5 @ 60kg');
    });
  });
}
