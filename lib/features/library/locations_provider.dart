import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/services/repositories/locations_repository_powersync.dart';

part 'locations_provider.g.dart';

@riverpod
Stream<List<TrainingLocation>> locations(Ref ref) {
  final repository = ref.watch(locationsRepositoryPowerSyncProvider);
  return repository.watchLocations();
}
