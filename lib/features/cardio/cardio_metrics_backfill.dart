import 'package:ethan_sync/ethan_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'cardio_import_controller.dart';

part 'cardio_metrics_backfill.g.dart';

/// Cardio zone rows are written when a workout is opened (HealthKit series).
/// Kept so existing watches still settle after import/sync; no mass backfill.
@riverpod
Future<void> cardioMetricsBackfill(Ref ref) async {
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
}
