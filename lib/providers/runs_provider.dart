import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';

part 'runs_provider.g.dart';

@riverpod
Stream<List<FitnessRun>> runsStream(Ref ref) {
  final runsRepository = ref.watch(runsRepositoryPowerSyncProvider);
  return runsRepository.watchRuns();
}

@riverpod
Stream<List<RunRoutePoint>> runRoutePoints(Ref ref, String runId) {
  final runsRepository = ref.watch(runsRepositoryPowerSyncProvider);
  return runsRepository.watchRoutePoints(runId);
}

@riverpod
Stream<List<RunHeartRateSample>> runHeartRateSamples(Ref ref, String runId) {
  final runsRepository = ref.watch(runsRepositoryPowerSyncProvider);
  return runsRepository.watchHeartRateSamples(runId);
}

@riverpod
class RunImportController extends _$RunImportController {
  @override
  Future<int> build() async {
    return 0;
  }

  Future<void> importRecentRuns({
    int maxWorkouts = 30,
    int maxRoutePoints = 1500,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final healthKitBridge = ref.read(healthKitBridgeProvider);
      final importedRuns = await healthKitBridge.fetchRecentRunningWorkouts(
        maxWorkouts: maxWorkouts,
        includeRoute: true,
        maxRoutePoints: maxRoutePoints,
        includeHeartRateSeries: true,
      );
      final runsRepository = ref.read(runsRepositoryPowerSyncProvider);
      await runsRepository.upsertImportedRuns(importedRuns);
      if (ref.mounted) {
        ref.invalidate(runsStreamProvider);
      }
      return importedRuns.length;
    });
  }
}
