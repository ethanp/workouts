import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';

part 'runs_provider.g.dart';

class RunImportProgress {
  const RunImportProgress({
    required this.totalRuns,
    required this.processedRuns,
    required this.inProgress,
    this.completedAt,
  });

  const RunImportProgress.idle()
    : totalRuns = 0,
      processedRuns = 0,
      inProgress = false,
      completedAt = null;

  final int totalRuns;
  final int processedRuns;
  final bool inProgress;
  final DateTime? completedAt;

  double get progressFraction {
    if (totalRuns <= 0) {
      return 0;
    }
    return processedRuns / totalRuns;
  }
}

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
  Future<RunImportProgress> build() async {
    return const RunImportProgress.idle();
  }

  Future<void> importRecentRuns({
    int maxWorkouts = 30,
    int maxRoutePoints = 1500,
  }) async {
    try {
      final healthKitBridge = ref.read(healthKitBridgeProvider);
      final importedRuns = await healthKitBridge.fetchRecentRunningWorkouts(
        maxWorkouts: maxWorkouts,
        includeRoute: true,
        maxRoutePoints: maxRoutePoints,
        includeHeartRateSeries: true,
      );

      if (!ref.mounted) {
        return;
      }

      state = AsyncValue.data(
        RunImportProgress(
          totalRuns: importedRuns.length,
          processedRuns: 0,
          inProgress: true,
        ),
      );

      final runsRepository = ref.read(runsRepositoryPowerSyncProvider);
      await runsRepository.upsertImportedRuns(
        importedRuns,
        onProgress: (processedRuns, totalRuns) {
          if (!ref.mounted) {
            return;
          }
          state = AsyncValue.data(
            RunImportProgress(
              totalRuns: totalRuns,
              processedRuns: processedRuns,
              inProgress: true,
            ),
          );
        },
      );

      if (ref.mounted) {
        ref.invalidate(runsStreamProvider);
        state = AsyncValue.data(
          RunImportProgress(
            totalRuns: importedRuns.length,
            processedRuns: importedRuns.length,
            inProgress: false,
            completedAt: DateTime.now(),
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
