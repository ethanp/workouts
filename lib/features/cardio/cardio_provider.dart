import 'package:ethan_sync/ethan_sync.dart' show syncStatusProvider;
import 'package:ethan_utils/ethan_utils.dart';
import 'dart:async';

import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/utils/error_bus.dart';

part 'cardio_provider.g.dart';

const _log = ELogger('CardioImportController');

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
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) {
    final streamController = StreamController<T>();
    ref.onDispose(streamController.close);
    return streamController.stream;
  }
  return watchFn(CardioRepositoryPowerSync(powerSyncDatabase));
}

@riverpod
Stream<List<CardioWorkout>> cardioWorkouts(Ref ref) => _watchRepo(
  ref,
  (cardioRepository) => cardioRepository.watchCardioWorkouts(),
);

@riverpod
Stream<List<CardioCalendarDay>> cardioCalendarDays(Ref ref) =>
    _watchRepo(ref, (cardioRepository) => cardioRepository.watchCalendarDays());

@riverpod
Stream<List<CardioRoutePoint>> cardioRoutePoints(Ref ref, String workoutId) =>
    _watchRepo(
      ref,
      (cardioRepository) => cardioRepository.watchRoutePoints(workoutId),
    );

@riverpod
Stream<List<CardioHeartRateSample>> cardioHeartRateSamples(
  Ref ref,
  String workoutId,
) => _watchRepo(
  ref,
  (cardioRepository) => cardioRepository.watchHeartRateSamples(workoutId),
);

@riverpod
Stream<List<CardioBestEffort>> cardioBestEfforts(Ref ref) =>
    _watchRepo(ref, (cardioRepository) => cardioRepository.watchBestEfforts());

/// Number of cardio workouts that haven't had heart rate zones computed yet.
/// Drives the "compute missing zones" UI affordance in settings.
@riverpod
Stream<int> workoutsMissingMetricsCount(Ref ref) => _watchRepo(
  ref,
  (cardioRepository) => cardioRepository.watchWorkoutsMissingMetricsCount(),
);

/// Backfills metrics for workouts missing computed zone data.
/// Gated on sync status: only runs after initial sync is complete
/// and connected, to avoid backfilling before data arrives.
@riverpod
Future<void> cardioMetricsBackfill(Ref ref) async {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) return;
  final syncStatus = ref.watch(syncStatusProvider).asData?.value;
  if (syncStatus == null ||
      syncStatus.hasSynced != true ||
      syncStatus.connected != true ||
      syncStatus.downloading) {
    return;
  }
  final countRows = await powerSyncDatabase.execute('''
    SELECT COUNT(*) AS cnt FROM cardio_workouts w
    LEFT JOIN cardio_computed_metrics m ON m.id = w.id
    WHERE m.id IS NULL
      OR m.zone1_seconds IS NULL
      OR (
        COALESCE(m.has_hr_samples, 0) = 0
        AND EXISTS (
          SELECT 1 FROM cardio_heart_rate_samples sample
          WHERE sample.workout_id = w.id
          LIMIT 1
        )
      )
  ''');
  final pendingCount = countRows.first['cnt'] as int? ?? 0;
  if (pendingCount == 0) return;

  await CardioRepositoryPowerSync(powerSyncDatabase).backfillMissingMetrics();
}

@riverpod
class CardioImportController extends _$CardioImportController {
  @override
  Future<CardioImportProgress> build() async {
    return const CardioImportProgress.idle();
  }

  @override
  set state(AsyncValue<CardioImportProgress> newState) {
    newState.whenOrNull(
      error: (error, stackTrace) =>
          _log.error('CardioImportController error', error, stackTrace),
    );
    super.state = newState;
  }

  static const _addingStatus =
      'Adding new workouts (skips ones already stored)…';
  static const _idleResetDelay = Duration(seconds: 3);

  Future<void> importRecentWorkouts({
    int maxWorkouts = 30,
    int maxRoutePoints = 1500,
  }) async {
    final powerSyncDatabase = ref.read(powerSyncDatabaseProvider).value;
    if (powerSyncDatabase == null) return;
    try {
      await _requestHealthKitAuthorization();
      final importedWorkouts = await _fetchRecentCardioWorkouts(
        maxWorkouts: maxWorkouts,
        maxRoutePoints: maxRoutePoints,
      );
      await _upsertImportedWorkouts(powerSyncDatabase, importedWorkouts);
    } catch (error, stackTrace) {
      _reportImportFailure(error, stackTrace);
    }
  }

  void _publishProgress({
    required String status,
    int totalWorkouts = 0,
    int processedWorkouts = 0,
  }) {
    if (!ref.mounted) return;
    state = AsyncValue.data(
      CardioImportProgress(
        totalWorkouts: totalWorkouts,
        processedWorkouts: processedWorkouts,
        inProgress: true,
        status: status,
      ),
    );
  }

  /// Triggers the OS permission prompt (no-op once granted). Routed through
  /// the notifier so any future observer of [healthKitPermissionProvider]
  /// sees the updated status; the notifier self-pins via `ref.keepAlive()`
  /// during the dialog await, so this `ref.read(...).method()` pattern is
  /// safe despite auto-dispose.
  Future<void> _requestHealthKitAuthorization() {
    _publishProgress(status: 'Requesting Apple Health access…');
    return ref
        .read(healthKitPermissionProvider.notifier)
        .requestAuthorization();
  }

  Future<List<Map<String, dynamic>>> _fetchRecentCardioWorkouts({
    required int maxWorkouts,
    required int maxRoutePoints,
  }) {
    _publishProgress(
      status: 'Fetching last $maxWorkouts workouts from Apple Health…',
    );
    return ref
        .read(healthKitBridgeProvider)
        .fetchRecentCardioWorkouts(
          maxWorkouts: maxWorkouts,
          includeRoute: true,
          maxRoutePoints: maxRoutePoints,
          includeHeartRateSeries: true,
        );
  }

  Future<void> _upsertImportedWorkouts(
    PowerSyncDatabase database,
    List<Map<String, dynamic>> importedWorkouts,
  ) async {
    _publishProgress(
      status: _addingStatus,
      totalWorkouts: importedWorkouts.length,
    );
    final newCount = await CardioRepositoryPowerSync(
      database,
    ).upsertImportedWorkouts(
      importedWorkouts,
      onProgress: (processedWorkouts, totalWorkouts) => _publishProgress(
        status: _addingStatus,
        totalWorkouts: totalWorkouts,
        processedWorkouts: processedWorkouts,
      ),
    );
    _publishCompletion(
      importedCount: importedWorkouts.length,
      newCount: newCount,
    );
  }

  void _publishCompletion({
    required int importedCount,
    required int newCount,
  }) {
    if (!ref.mounted) return;
    ref.invalidate(cardioWorkoutsProvider);
    state = AsyncValue.data(
      CardioImportProgress(
        totalWorkouts: importedCount,
        processedWorkouts: importedCount,
        newWorkouts: newCount,
        inProgress: false,
        completedAt: DateTime.now(),
        status: _completionStatus(
          importedCount: importedCount,
          newCount: newCount,
        ),
      ),
    );
    _scheduleResetToIdle();
  }

  String _completionStatus({
    required int importedCount,
    required int newCount,
  }) {
    if (importedCount == 0) {
      return 'No workouts found. Check Apple Health permissions in Settings.';
    }
    return 'Done. Found $importedCount workouts, $newCount new.';
  }

  void _scheduleResetToIdle() {
    Future.delayed(_idleResetDelay, () {
      if (!ref.mounted) return;
      state = const AsyncValue.data(CardioImportProgress.idle());
    });
  }

  void _reportImportFailure(Object error, StackTrace stackTrace) {
    _log.error('importRecentWorkouts failed', error, stackTrace);
    errorBus.add('Apple Health import: $error');
    if (!ref.mounted) return;
    state = AsyncValue.error(error, stackTrace);
  }
}
