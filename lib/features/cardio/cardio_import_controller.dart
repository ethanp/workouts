import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/services/repositories/workout_route_store.dart';
import 'package:workouts/error_bus.dart';

import 'cardio_browse_providers.dart';

part 'cardio_import_controller.g.dart';

const _log = ELogger('CardioImportController');

class CardioImportProgress {
  const new({
    required this.totalWorkouts,
    required this.processedWorkouts,
    required this.inProgress,
    this.writtenWorkouts = 0,
    this.skippedUnchanged = 0,
    this.removedWorkouts = 0,
    this.newWorkouts = 0,
    this.completedAt,
    this.status = '',
  });

  const new idle()
    : totalWorkouts = 0,
      processedWorkouts = 0,
      writtenWorkouts = 0,
      skippedUnchanged = 0,
      removedWorkouts = 0,
      newWorkouts = 0,
      inProgress = false,
      completedAt = null,
      status = '';

  final int totalWorkouts;
  final int processedWorkouts;
  final int writtenWorkouts;
  final int skippedUnchanged;
  final int removedWorkouts;
  final int newWorkouts;
  final bool inProgress;
  final DateTime? completedAt;
  final String status;

  double get progressFraction {
    if (totalWorkouts <= 0) return 0;
    return processedWorkouts / totalWorkouts;
  }
}

@riverpod
class CardioImportController() extends _$CardioImportController {
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

  static const _idleResetDelay = Duration(seconds: 3);

  Future<void> importRecentWorkouts({
    int maxWorkouts = 0,
    int maxRoutePoints = 1500,
    bool replaceStored = false,
  }) async {
    final powerSyncDatabase = ref.read(powerSyncDatabaseProvider).value;
    if (powerSyncDatabase == null) return;
    final keepImportAlive = ref.keepAlive();
    try {
      await _requestHealthKitAuthorization();
      final cardioRepository = CardioRepositoryPowerSync(powerSyncDatabase);
      final syncOutcome = await _syncWorkoutsOneByOne(
        cardioRepository,
        maxWorkouts: maxWorkouts,
        maxRoutePoints: maxRoutePoints,
        replaceStored: replaceStored,
      );
      await _computeZonesBeforeComplete();
      final routeOutcome = await _storeMissingRoutes();
      _publishCompletion(
        syncOutcome,
        replaceStored: replaceStored,
        routeOutcome: routeOutcome,
      );
    } catch (error, stackTrace) {
      _reportImportFailure(error, stackTrace);
    } finally {
      keepImportAlive.close();
    }
  }

  Future<void> storeRoutes() async {
    final powerSyncDatabase = ref.read(powerSyncDatabaseProvider).value;
    if (powerSyncDatabase == null) return;
    final keepImportAlive = ref.keepAlive();
    try {
      await _requestHealthKitAuthorization();
      final outcome = await _storeMissingRoutes();
      if (!ref.mounted) return;
      state = AsyncValue.data(
        CardioImportProgress(
          totalWorkouts: outcome.stored + outcome.withoutGps + outcome.failed,
          processedWorkouts:
              outcome.stored + outcome.withoutGps + outcome.failed,
          writtenWorkouts: outcome.stored,
          inProgress: false,
          completedAt: DateTime.now(),
          status: _routeStoreStatus(outcome),
        ),
      );
      _scheduleResetToIdle();
    } catch (error, stackTrace) {
      _reportImportFailure(error, stackTrace);
    } finally {
      keepImportAlive.close();
    }
  }

  String _routeStoreStatus(RouteStoreOutcome outcome) {
    if (outcome.stored == 0 && outcome.withoutGps == 0 && outcome.failed == 0) {
      return outcome.alreadyStored == 0
          ? 'No outdoor workouts to store routes for.'
          : 'Done. Every outdoor workout already has a stored route.';
    }
    final stored = outcome.stored == 1 ? '1 route' : '${outcome.stored} routes';
    final withoutGps = outcome.withoutGps == 0
        ? null
        : '${outcome.withoutGps} without GPS';
    final failed = outcome.failed == 0 ? null : '${outcome.failed} failed';
    return 'Done. Stored $stored'
        '${withoutGps == null ? '' : ', $withoutGps'}'
        '${failed == null ? '' : ', $failed'}.';
  }

  void _publishProgress({
    required String status,
    int totalWorkouts = 0,
    int processedWorkouts = 0,
    int writtenWorkouts = 0,
    int skippedUnchanged = 0,
  }) {
    if (!ref.mounted) return;
    state = AsyncValue.data(
      CardioImportProgress(
        totalWorkouts: totalWorkouts,
        processedWorkouts: processedWorkouts,
        writtenWorkouts: writtenWorkouts,
        skippedUnchanged: skippedUnchanged,
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

  Future<_AppleHealthSyncOutcome> _syncWorkoutsOneByOne(
    CardioRepositoryPowerSync cardioRepository, {
    required int maxWorkouts,
    required int maxRoutePoints,
    required bool replaceStored,
  }) async {
    _publishProgress(status: 'Asking Apple Health for workouts…');
    final alreadyStored = replaceStored
        ? null
        : await cardioRepository.storedAppleHealthFingerprints();
    var writtenCount = 0;
    var skippedCount = 0;
    final listing = await ref
        .read(healthKitBridgeProvider)
        .importCardioWorkouts(
          maxWorkouts: maxWorkouts,
          includeRoute: false,
          includeHeartRateSeries: false,
          includeAssociatedSeries: false,
          maxRoutePoints: maxRoutePoints,
          skipUnchanged: alreadyStored?.fingerprints ?? const [],
          onProgress: (inspectProgress) => _publishProgress(
            status: inspectProgress.caption,
            totalWorkouts: inspectProgress.totalWorkouts,
            processedWorkouts: inspectProgress.completedWorkouts,
            writtenWorkouts: writtenCount,
            skippedUnchanged: skippedCount,
          ),
          onWorkout: (workout) async {
            if (workout['skippedUnchanged'] == true) {
              skippedCount++;
              return;
            }
            if (await cardioRepository.insertImportedWorkout(workout)) {
              writtenCount++;
            }
          },
        );
    var removedCount = 0;
    if (listing.seenExternalIds.isNotEmpty) {
      removedCount = await cardioRepository
          .deleteAppleHealthWorkoutsMissingFrom(
            listing.seenExternalIds.toSet(),
          );
    }
    return _AppleHealthSyncOutcome(
      listedCount: listing.listedCount,
      writtenCount: writtenCount,
      skippedCount: skippedCount,
      removedCount: removedCount,
    );
  }

  Future<RouteStoreOutcome> _storeMissingRoutes() {
    final powerSyncDatabase = ref.read(powerSyncDatabaseProvider).value;
    if (powerSyncDatabase == null) {
      return Future.value(
        const RouteStoreOutcome(
          stored: 0,
          alreadyStored: 0,
          withoutGps: 0,
          failed: 0,
        ),
      );
    }
    _publishProgress(status: 'Storing routes…');
    return WorkoutRouteStore(
      powerSync: powerSyncDatabase,
      healthKit: ref.read(healthKitBridgeProvider),
      postgrestUrl: ref.read(postgrestUrlProvider),
    ).storeMissing(
      onProgress: (done, total) => _publishProgress(
        status: 'Storing routes…',
        totalWorkouts: total,
        processedWorkouts: done,
      ),
    );
  }

  void _publishCompletion(
    _AppleHealthSyncOutcome syncOutcome, {
    required bool replaceStored,
    required RouteStoreOutcome routeOutcome,
  }) {
    if (!ref.mounted) return;
    ref.invalidate(cardioWorkoutsProvider);
    state = AsyncValue.data(
      CardioImportProgress(
        totalWorkouts: syncOutcome.listedCount,
        processedWorkouts: syncOutcome.listedCount,
        writtenWorkouts: syncOutcome.writtenCount,
        skippedUnchanged: syncOutcome.skippedCount,
        removedWorkouts: syncOutcome.removedCount,
        newWorkouts: syncOutcome.writtenCount,
        inProgress: false,
        completedAt: DateTime.now(),
        status: _completionStatus(
          syncOutcome,
          replaceStored: replaceStored,
          routeOutcome: routeOutcome,
        ),
      ),
    );
    _scheduleResetToIdle();
  }

  String _completionStatus(
    _AppleHealthSyncOutcome syncOutcome, {
    required bool replaceStored,
    required RouteStoreOutcome routeOutcome,
  }) {
    final routes = _storedRoutesSentence(routeOutcome);
    if (syncOutcome.listedCount == 0) {
      return 'No workouts found. Check Apple Health permissions in Settings.$routes';
    }
    if (replaceStored) {
      final written = syncOutcome.writtenCount;
      return 'Done. Replaced $written ${written == 1 ? 'workout' : 'workouts'} from Apple Health.$routes';
    }
    final written = syncOutcome.writtenCount;
    final skipped = syncOutcome.skippedCount;
    final writtenCaption = written == 0
        ? 'no new or changed workouts'
        : '$written new or changed ${written == 1 ? 'workout' : 'workouts'}';
    final skippedCaption = skipped == 0 ? null : '$skipped already present';
    final removedCaption = syncOutcome.removedCount == 0
        ? null
        : 'removed ${syncOutcome.removedCount} no longer in Apple Health';
    return 'Done. Pulled $writtenCaption'
        '${skippedCaption == null ? '' : ', $skippedCaption'}'
        '${removedCaption == null ? '' : ', $removedCaption'}.$routes';
  }

  String _storedRoutesSentence(RouteStoreOutcome outcome) {
    if (outcome.stored == 0 && outcome.failed == 0) return '';
    final stored = outcome.stored == 1 ? '1 route' : '${outcome.stored} routes';
    final failed = outcome.failed == 0 ? '' : ', ${outcome.failed} failed';
    return ' Stored $stored$failed.';
  }

  Future<void> _computeZonesBeforeComplete() async {
    _publishProgress(status: 'Computing heart-rate zones…');
    await ref
        .read(metricsBackfillControllerProvider.notifier)
        .runBackfill(
          onZoneProgress: (done, total) {
            _publishProgress(
              status: 'Computing heart-rate zones…',
              totalWorkouts: total,
              processedWorkouts: done,
            );
          },
        );
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

class const _AppleHealthSyncOutcome({
  required final int listedCount,
  required final int writtenCount,
  required final int skippedCount,
  required final int removedCount,
});
