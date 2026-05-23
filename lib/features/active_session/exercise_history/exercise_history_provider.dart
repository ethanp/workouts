import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';

part 'exercise_history_provider.g.dart';

@riverpod
Future<List<ExerciseHistoryEntry>> exerciseHistory(
  Ref ref,
  String exerciseId,
) {
  final repository = ref.watch(sessionRepositoryPowerSyncProvider);
  return repository.fetchExerciseHistory(exerciseId: exerciseId);
}
