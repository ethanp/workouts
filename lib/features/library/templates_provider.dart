import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

part 'templates_provider.g.dart';

@riverpod
Stream<List<WorkoutTemplate>> workoutTemplates(Ref ref) async* {
  final repository = ref.watch(templateRepositoryPowerSyncProvider);
  yield* repository.watchTemplates();
}

@riverpod
Future<Map<String, WorkoutTemplate>> templatesMap(Ref ref) async {
  final templates = await ref.watch(workoutTemplatesProvider.future);
  return {for (final template in templates) template.id: template};
}

@riverpod
Future<List<WorkoutExercise>> allExercises(Ref ref) async {
  final templates = await ref.watch(workoutTemplatesProvider.future);
  return templates
      .expand((workoutTemplate) => workoutTemplate.blocks)
      .expand((workoutBlock) => workoutBlock.exercises)
      // Remove duplicates by name, instead of naively deduplicating by object
      // identity, since exercises across templates have different UUIDs.
      .fold<Map<String, WorkoutExercise>>(
        {},
        (exerciseByName, workoutExercise) =>
            exerciseByName..[workoutExercise.name] = workoutExercise,
      )
      .values
      .toList()
    ..sort(
      (firstExercise, secondExercise) =>
          firstExercise.name.compareTo(secondExercise.name),
    );
}
