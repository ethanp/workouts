import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/template_repository.dart';

part 'today_template_provider.g.dart';

@riverpod
Future<WorkoutTemplate?> todayTemplate(Ref ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.fetchTemplates().then((templates) => templates.firstOrNull);
}
