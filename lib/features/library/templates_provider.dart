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

/// Live single-template lookup. Re-emits whenever [workoutTemplatesProvider]
/// changes — including any `updated_at` touch on the template row, which is
/// how mutators like `addWarmupSet`/`removeWarmupSet` propagate without
/// going through full `saveTemplate`. Returns `null` while the list is
/// loading or if the template has been deleted.
@riverpod
WorkoutTemplate? templateById(Ref ref, String templateId) {
  final templatesAsync = ref.watch(workoutTemplatesProvider);
  final templates = templatesAsync.value;
  if (templates == null) return null;
  for (final template in templates) {
    if (template.id == templateId) return template;
  }
  return null;
}

@riverpod
Future<List<WorkoutExercise>> allExercises(Ref ref) async {
  final repository = ref.watch(templateRepositoryPowerSyncProvider);
  return repository.fetchExercises();
}
