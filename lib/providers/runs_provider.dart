import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_calendar_day.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
import 'package:workouts/utils/zone2_calculator.dart';

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

/// Watches [powerSyncDatabaseProvider] and, once the DB is ready, passes a
/// [RunsRepositoryPowerSync] to [watchFn] and returns its stream.
/// While the DB is still initializing the returned stream never emits,
/// keeping the StreamProvider in loading state rather than error state.
Stream<T> _watchRepo<T>(
  Ref ref,
  Stream<T> Function(RunsRepositoryPowerSync) watchFn,
) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) {
    final ctrl = StreamController<T>();
    ref.onDispose(ctrl.close);
    return ctrl.stream;
  }
  return watchFn(RunsRepositoryPowerSync(db));
}

@riverpod
Stream<List<FitnessRun>> runsStream(Ref ref) =>
    _watchRepo(ref, (repo) => repo.watchRuns());

@riverpod
Stream<List<RunCalendarDay>> runCalendarDays(Ref ref) =>
    _watchRepo(ref, (repo) => repo.watchCalendarDays());

@riverpod
Stream<List<RunRoutePoint>> runRoutePoints(Ref ref, String runId) =>
    _watchRepo(ref, (repo) => repo.watchRoutePoints(runId));

@riverpod
Stream<List<RunHeartRateSample>> runHeartRateSamples(Ref ref, String runId) =>
    _watchRepo(ref, (repo) => repo.watchHeartRateSamples(runId));

/// Fires the startup backfill for any runs missing computed Zone 2 metrics.
/// Watch this provider in [RunCalendarScreen] to trigger it lazily.
@riverpod
Future<void> runMetricsBackfill(Ref ref) async {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) return; // Rebuilds automatically when DB resolves.
  final maxHR = ref.watch(maxHeartRateProvider);
  final bounds = zone2Bounds(maxHR);
  await RunsRepositoryPowerSync(db).backfillMissingMetrics(
    lowerBpm: bounds.lower,
    upperBpm: bounds.upper,
  );
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
    final db = ref.read(powerSyncDatabaseProvider).value;
    if (db == null) return;
    try {
      final healthKitBridge = ref.read(healthKitBridgeProvider);
      final runsRepository = RunsRepositoryPowerSync(db);
      final importedRuns = await healthKitBridge.fetchRecentRunningWorkouts(
        maxWorkouts: maxWorkouts,
        includeRoute: true,
        maxRoutePoints: maxRoutePoints,
        includeHeartRateSeries: true,
      );
      if (ref.mounted) {
        state = AsyncValue.data(
          RunImportProgress(
            totalRuns: importedRuns.length,
            processedRuns: 0,
            inProgress: true,
          ),
        );
      }

      final maxHR = ref.read(maxHeartRateProvider);
      final bounds = zone2Bounds(maxHR);
      await runsRepository.upsertImportedRuns(
        importedRuns,
        zone2LowerBpm: bounds.lower,
        zone2UpperBpm: bounds.upper,
        onProgress: (processedRuns, totalRuns) {
          if (ref.mounted) {
            state = AsyncValue.data(
              RunImportProgress(
                totalRuns: totalRuns,
                processedRuns: processedRuns,
                inProgress: true,
              ),
            );
          }
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
      if (ref.mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
}
