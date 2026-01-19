import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/services/repositories/heart_rate_samples_repository_powersync.dart';

part 'heart_rate_samples_provider.g.dart';

@riverpod
Stream<List<HeartRateSample>> heartRateSamplesStream(
  Ref ref,
  String sessionId,
) {
  final repo = ref.watch(heartRateSamplesRepositoryPowerSyncProvider);
  return repo.watchSamplesForSession(sessionId);
}
