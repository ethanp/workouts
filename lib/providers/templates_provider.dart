import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/template_repository.dart';

part 'templates_provider.g.dart';

@riverpod
Future<List<WorkoutTemplate>> workoutTemplates(Ref ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.fetchTemplates();
}

@riverpod
Future<Map<String, WorkoutTemplate>> templatesMap(Ref ref) async {
  final templates = await ref.watch(workoutTemplatesProvider.future);
  return {for (final template in templates) template.id: template};
}
