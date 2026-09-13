import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
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
      );
      _publishCompletion(syncOutcome);
    } catch (error, stackTrace) {
      _reportImportFailure(error, stackTrace);
    } finally {
      keepImportAlive.close();
    }
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
  }) async {
    _publishProgress(status: 'Asking Apple Health for workouts…');
    final alreadyStored = await cardioRepository.storedAppleHealthFingerprints();
    var writtenCount = 0;
    var skippedCount = 0;
    final listing = await ref
        .read(healthKitBridgeProvider)
        .importCardioWorkouts(
          maxWorkouts: maxWorkouts,
          maxRoutePoints: maxRoutePoints,
          skipUnchanged: alreadyStored.fingerprints,
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
          .deleteAppleHealthWorkoutsMissingFrom(listing.seenExternalIds.toSet());
    }
    return _AppleHealthSyncOutcome(
      listedCount: listing.listedCount,
      writtenCount: writtenCount,
      skippedCount: skippedCount,
      removedCount: removedCount,
    );
  }

  void _publishCompletion(_AppleHealthSyncOutcome syncOutcome) {
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
        status: _completionStatus(syncOutcome),
      ),
    );
    _scheduleResetToIdle();
  }

  String _completionStatus(_AppleHealthSyncOutcome syncOutcome) {
    if (syncOutcome.listedCount == 0) {
      return 'No workouts found. Check Apple Health permissions in Settings.';
    }
    final written = syncOutcome.writtenCount;
    final skipped = syncOutcome.skippedCount;
    final writtenCaption = written == 0
        ? 'no new or changed workouts'
        : '$written new or changed ${written == 1 ? 'workout' : 'workouts'}';
    final skippedCaption = skipped == 0
        ? null
        : '$skipped already present';
    final removedCaption = syncOutcome.removedCount == 0
        ? null
        : 'removed ${syncOutcome.removedCount} no longer in Apple Health';
    return 'Done. Pulled $writtenCaption'
        '${skippedCaption == null ? '' : ', $skippedCaption'}'
        '${removedCaption == null ? '' : ', $removedCaption'}.';
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
