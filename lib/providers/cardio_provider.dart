import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'cardio_provider.g.dart';

class CardioImportProgress {
  const CardioImportProgress({
    required this.totalWorkouts,
    required this.processedWorkouts,
    required this.inProgress,
    this.newWorkouts = 0,
    this.completedAt,
    this.status = '',
  });

  const CardioImportProgress.idle()
    : totalWorkouts = 0,
      processedWorkouts = 0,
      newWorkouts = 0,
      inProgress = false,
      completedAt = null,
      status = '';

  final int totalWorkouts;
  final int processedWorkouts;
  final int newWorkouts;
  final bool inProgress;
  final DateTime? completedAt;
  final String status;

  double get progressFraction {
    if (totalWorkouts <= 0) return 0;
    return processedWorkouts / totalWorkouts;
  }
}

Stream<T> _watchRepo<T>(
  Ref ref,
  Stream<T> Function(CardioRepositoryPowerSync) watchFn,
) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) {
    final ctrl = StreamController<T>();
    ref.onDispose(ctrl.close);
    return ctrl.stream;
  }
  return watchFn(CardioRepositoryPowerSync(db));
}

@riverpod
Stream<List<CardioWorkout>> cardioWorkouts(Ref ref) =>
    _watchRepo(ref, (repo) => repo.watchCardioWorkouts());

@riverpod
Stream<List<CardioCalendarDay>> cardioCalendarDays(Ref ref) =>
    _watchRepo(ref, (repo) => repo.watchCalendarDays());

@riverpod
Stream<List<CardioRoutePoint>> cardioRoutePoints(
        Ref ref, String workoutId) =>
    _watchRepo(ref, (repo) => repo.watchRoutePoints(workoutId));

@riverpod
Stream<List<CardioHeartRateSample>> cardioHeartRateSamples(
        Ref ref, String workoutId) =>
    _watchRepo(ref, (repo) => repo.watchHeartRateSamples(workoutId));

@riverpod
Stream<List<CardioBestEffort>> cardioBestEfforts(Ref ref) =>
    _watchRepo(ref, (repo) => repo.watchBestEfforts());

/// Backfills metrics for workouts missing computed zone data.
@riverpod
Future<void> cardioMetricsBackfill(Ref ref) async {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) return;
  final maxHR = ref.watch(maxHeartRateProvider);
  final restingHR = ref.watch(restingHeartRateProvider);
  final trainingLoad = TrainingLoadCalculator(
    maxHeartRate: maxHR,
    restingHeartRate: restingHR,
  );
  await CardioRepositoryPowerSync(db)
      .backfillMissingMetrics(trainingLoad: trainingLoad);
}

@riverpod
class CardioImportController extends _$CardioImportController {
  @override
  Future<CardioImportProgress> build() async {
    return const CardioImportProgress.idle();
  }

  Future<void> importRecentWorkouts({
    int maxWorkouts = 30,
    int maxRoutePoints = 1500,
  }) async {
    final db = ref.read(powerSyncDatabaseProvider).value;
    if (db == null) return;
    try {
      final healthKitBridge = ref.read(healthKitBridgeProvider);
      final cardioRepository = CardioRepositoryPowerSync(db);
      if (ref.mounted) {
        state = AsyncValue.data(
          CardioImportProgress(
            totalWorkouts: 0,
            processedWorkouts: 0,
            inProgress: true,
            status:
                'Fetching last $maxWorkouts workouts from Apple Health…',
          ),
        );
      }
      final importedWorkouts =
          await healthKitBridge.fetchRecentCardioWorkouts(
        maxWorkouts: maxWorkouts,
        includeRoute: true,
        maxRoutePoints: maxRoutePoints,
        includeHeartRateSeries: true,
      );
      if (ref.mounted) {
        state = AsyncValue.data(
          CardioImportProgress(
            totalWorkouts: importedWorkouts.length,
            processedWorkouts: 0,
            inProgress: true,
            status: 'Adding new workouts (skips ones already stored)…',
          ),
        );
      }

      final maxHR = ref.read(maxHeartRateProvider);
      final restingHR = ref.read(restingHeartRateProvider);
      final trainingLoad = TrainingLoadCalculator(
        maxHeartRate: maxHR,
        restingHeartRate: restingHR,
      );
      final newCount = await cardioRepository.upsertImportedWorkouts(
        importedWorkouts,
        trainingLoad: trainingLoad,
        onProgress: (processedWorkouts, totalWorkouts) {
          if (ref.mounted) {
            state = AsyncValue.data(
              CardioImportProgress(
                totalWorkouts: totalWorkouts,
                processedWorkouts: processedWorkouts,
                inProgress: true,
                status:
                    'Adding new workouts (skips ones already stored)…',
              ),
            );
          }
        },
      );

      if (ref.mounted) {
        ref.invalidate(cardioWorkoutsProvider);
        final doneStatus = importedWorkouts.isEmpty
            ? 'No workouts found. Check Apple Health permissions in Settings.'
            : 'Done. Found ${importedWorkouts.length} workouts, $newCount new.';
        state = AsyncValue.data(
          CardioImportProgress(
            totalWorkouts: importedWorkouts.length,
            processedWorkouts: importedWorkouts.length,
            newWorkouts: newCount,
            inProgress: false,
            completedAt: DateTime.now(),
            status: doneStatus,
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (ref.mounted) {
            state =
                const AsyncValue.data(CardioImportProgress.idle());
          }
        });
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
}
