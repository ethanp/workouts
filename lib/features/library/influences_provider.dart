import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';

part 'influences_provider.g.dart';

@riverpod
Stream<List<TrainingInfluence>> influences(Ref ref) {
  final repository = ref.watch(influencesRepositoryPowerSyncProvider);
  return repository.watchInfluences();
}

@riverpod
Stream<List<TrainingInfluence>> activeInfluences(Ref ref) {
  final repository = ref.watch(influencesRepositoryPowerSyncProvider);
  return repository.watchActiveInfluences();
}
