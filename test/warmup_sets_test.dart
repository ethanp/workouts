import 'package:flutter_test/flutter_test.dart';

import 'package:workouts/models/exercise_set_metrics.dart';
import 'package:workouts/models/warmup_sets.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';

WorkoutExercise _exercise({
  ExerciseModality modality = ExerciseModality.reps,
  ExerciseSetMetricsStyle setMetricsStyle =
      ExerciseSetMetricsStyle.repsAndWeight,
  Duration? workDuration,
  List<PlannedSet> plannedSets = const [],
}) => WorkoutExercise(
  id: 'ex',
  name: 'Test Exercise',
  modality: modality,
  prescription: 'legacy',
  setMetricsStyle: setMetricsStyle,
  workDuration: workDuration,
  plannedSets: plannedSets,
);

void main() {
  group('PlannedSet.newWarmup', () {
    test('copies sibling and forces type to warmup', () {
      const sibling = PlannedSet(
        type: PlannedSetType.warmup,
        reps: 5,
        weight: Weight.kilograms(40),
      );
      final exercise = _exercise(plannedSets: const [sibling]);

      final result = PlannedSet.newWarmup(
        exercise: exercise,
        sibling: sibling,
      );

      expect(result.type, PlannedSetType.warmup);
      expect(result.reps, 5);
      expect(result.weight, const Weight.kilograms(40));
    });

    test('coerces a working sibling to warmup type', () {
      const workingSibling = PlannedSet(
        reps: 8,
        weight: Weight.kilograms(20),
      );

      final result = PlannedSet.newWarmup(
        exercise: _exercise(plannedSets: const [workingSibling]),
        sibling: workingSibling,
      );

      expect(result.type, PlannedSetType.warmup);
      expect(result.reps, 8);
    });

    test(
      'inherits cadence from first working set when no sibling is given',
      () {
        const workingSet = PlannedSet(
          reps: 5,
          weight: Weight.kilograms(60),
          targetIntensity: 'RIR 2',
        );
        final exercise = _exercise(plannedSets: const [workingSet]);

        final result = PlannedSet.newWarmup(exercise: exercise);

        expect(result.type, PlannedSetType.warmup);
        expect(result.reps, 5);
        expect(result.weight, isNull);
        expect(result.targetIntensity, isNull);
      },
    );

    test(
      'falls back to reps: 8 for empty rep-modality exercises',
      () {
        final exercise = _exercise(
          modality: ExerciseModality.reps,
          setMetricsStyle: ExerciseSetMetricsStyle.repsAndWeight,
        );

        final result = PlannedSet.newWarmup(exercise: exercise);

        expect(result.type, PlannedSetType.warmup);
        expect(result.reps, 8);
        expect(result.duration, isNull);
      },
    );

    test(
      'falls back to workDuration for empty timed-modality exercises',
      () {
        final exercise = _exercise(
          modality: ExerciseModality.timed,
          setMetricsStyle: ExerciseSetMetricsStyle.durationOnly,
          workDuration: const Duration(seconds: 45),
        );

        final result = PlannedSet.newWarmup(exercise: exercise);

        expect(result.type, PlannedSetType.warmup);
        expect(result.reps, isNull);
        expect(result.duration, const Duration(seconds: 45));
      },
    );

    test(
      'falls back to 30s when timed exercise has no workDuration',
      () {
        final exercise = _exercise(
          modality: ExerciseModality.hold,
          setMetricsStyle: ExerciseSetMetricsStyle.durationOnly,
        );

        final result = PlannedSet.newWarmup(exercise: exercise);

        expect(result.duration, const Duration(seconds: 30));
      },
    );
  });

  group('WarmupSets predicates', () {
    final exercise = _exercise();

    test('canAdd is true while unlogged sets remain', () {
      const plannedSets = [
        PlannedSet(reps: 5, weight: Weight.kilograms(60)),
        PlannedSet(reps: 5, weight: Weight.kilograms(60)),
      ];
      final warmupSets = WarmupSets(
        plannedSets: plannedSets,
        exercise: exercise,
        loggedSetCount: 1,
      );

      expect(warmupSets.canAdd, isTrue);
    });

    test('canAdd is false when fully logged', () {
      const plannedSets = [PlannedSet(reps: 5, weight: Weight.kilograms(60))];
      final warmupSets = WarmupSets(
        plannedSets: plannedSets,
        exercise: exercise,
        loggedSetCount: 1,
      );

      expect(warmupSets.canAdd, isFalse);
    });

    test('canRemove iff next unlogged set is a warmup', () {
      const warmup = PlannedSet(
        type: PlannedSetType.warmup,
        reps: 8,
        weight: Weight.kilograms(20),
      );
      const working = PlannedSet(reps: 5, weight: Weight.kilograms(60));

      final canRemove = WarmupSets(
        plannedSets: const [warmup, working],
        exercise: exercise,
        loggedSetCount: 0,
      );
      expect(canRemove.canRemove, isTrue);

      final cannotRemove = WarmupSets(
        plannedSets: const [warmup, working],
        exercise: exercise,
        loggedSetCount: 1,
      );
      expect(cannotRemove.canRemove, isFalse);
    });
  });

  group('WarmupSets.withOneAdded', () {
    test('inserts at loggedSetCount index', () {
      const warmup = PlannedSet(
        type: PlannedSetType.warmup,
        reps: 8,
        weight: Weight.kilograms(20),
      );
      const working = PlannedSet(reps: 5, weight: Weight.kilograms(60));
      final warmupSets = WarmupSets(
        plannedSets: const [warmup, warmup, working, working, working],
        exercise: _exercise(plannedSets: const [warmup, working]),
        loggedSetCount: 2,
      );

      final next = warmupSets.withOneAdded();

      expect(next.length, 6);
      expect(next[0].type, PlannedSetType.warmup);
      expect(next[1].type, PlannedSetType.warmup);
      expect(next[2].type, PlannedSetType.warmup);
      expect(next[3].type, PlannedSetType.working);
      expect(next[4].type, PlannedSetType.working);
      expect(next[5].type, PlannedSetType.working);
    });

    test(
      'mirrors the next unlogged warmup when one exists',
      () {
        const sibling = PlannedSet(
          type: PlannedSetType.warmup,
          reps: 8,
          weight: Weight.kilograms(20),
        );
        const working = PlannedSet(reps: 5, weight: Weight.kilograms(60));
        final warmupSets = WarmupSets(
          plannedSets: const [sibling, working],
          exercise: _exercise(plannedSets: const [sibling, working]),
          loggedSetCount: 0,
        );

        final next = warmupSets.withOneAdded();

        expect(next[0].reps, 8);
        expect(next[0].weight, const Weight.kilograms(20));
        expect(next[0].type, PlannedSetType.warmup);
      },
    );

    test(
      'derives from first working set when no warmup is in the unlogged tail',
      () {
        const working = PlannedSet(
          reps: 5,
          weight: Weight.kilograms(60),
          targetIntensity: 'RIR 2',
        );
        final exercise = _exercise(plannedSets: const [working, working]);
        final warmupSets = WarmupSets(
          plannedSets: const [working, working],
          exercise: exercise,
          loggedSetCount: 0,
        );

        final next = warmupSets.withOneAdded();

        expect(next.first.type, PlannedSetType.warmup);
        expect(next.first.reps, 5);
        expect(next.first.weight, isNull);
        expect(next.first.targetIntensity, isNull);
      },
    );
  });

  group('WarmupSets.withOneRemoved', () {
    test('drops the warmup at loggedSetCount', () {
      const warmup = PlannedSet(
        type: PlannedSetType.warmup,
        reps: 8,
        weight: Weight.kilograms(20),
      );
      const working = PlannedSet(reps: 5, weight: Weight.kilograms(60));
      final warmupSets = WarmupSets(
        plannedSets: const [warmup, warmup, working],
        exercise: _exercise(),
        loggedSetCount: 1,
      );

      final next = warmupSets.withOneRemoved();

      expect(next, const [warmup, working]);
    });

    test('throws when canRemove is false', () {
      const working = PlannedSet(reps: 5, weight: Weight.kilograms(60));
      final warmupSets = WarmupSets(
        plannedSets: const [working],
        exercise: _exercise(),
        loggedSetCount: 0,
      );

      expect(() => warmupSets.withOneRemoved(), throwsStateError);
    });
  });
}
