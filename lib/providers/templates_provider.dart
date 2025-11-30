import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/repositories/template_repository.dart';

part 'templates_provider.g.dart';

@riverpod
Future<List<WorkoutTemplate>> workoutTemplates(Ref ref) async {
  final repository = ref.watch(templateRepositoryProvider);

  // Watch for sync events and refresh when templates change
  ref.listen(syncEventsProvider, (previous, next) {
    next.whenData((event) {
      if (event == 'templates') {
        ref.invalidateSelf();
      }
    });
  });

  return repository.fetchTemplates();
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
      .expand((t) => t.blocks)
      .expand((b) => b.exercises)
      // Remove duplicates by name, instead of naively deduplicating by object
      // identity, since exercises across templates have different UUIDs.
      .fold<Map<String, WorkoutExercise>>({}, (m, e) => m..[e.name] = e)
      .values
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}
