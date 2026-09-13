import 'package:ethan_sync/ethan_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';

import 'cardio_import_controller.dart';

part 'cardio_metrics_backfill.g.dart';

/// Backfills metrics for workouts missing computed zone data.
/// Gated on sync status: only runs after initial sync is complete
/// and connected, to avoid backfilling before data arrives.
/// Skips while Apple Health import is writing the same local-only rows.
@riverpod
Future<void> cardioMetricsBackfill(Ref ref) async {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) return;
  final CardioImportProgress? importProgress = ref
      .watch(cardioImportControllerProvider)
      .asData
      ?.value;
  if (importProgress != null && importProgress.inProgress) return;
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
