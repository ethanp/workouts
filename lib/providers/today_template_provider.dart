import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';

part 'today_template_provider.g.dart';

@riverpod
Stream<List<WorkoutTemplate>> todayTemplates(Ref ref) async* {
  final repository = ref.watch(templateRepositoryPowerSyncProvider);
  yield* repository.watchTemplates();
}

@riverpod
class ExpandedTemplates extends _$ExpandedTemplates {
  @override
  Set<String> build() => {};

  void toggle(String templateId) {
    if (state.contains(templateId)) {
      state = {...state}..remove(templateId);
    } else {
      state = {...state, templateId};
    }
  }

  bool isExpanded(String templateId) => state.contains(templateId);
}
