import 'dart:io';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../history/activity_provider.dart';
import 'cardio_browse_providers.dart';
import 'cardio_import_controller.dart';

part 'cardio_metrics_backfill.g.dart';

/// Fills zone minutes for workouts that do not yet have an expanded
/// heart-rate sample count. Apple Health sync awaits the same pass before
/// it reports done.
@riverpod
Future<void> cardioMetricsBackfill(Ref ref) async {
  if (!Platform.isIOS) return;
  final AsyncValue<CardioImportProgress> importAsync = ref.watch(
    cardioImportControllerProvider,
  );
  if (importAsync.isLoading || importAsync.hasError) return;
  if (importAsync.value?.inProgress ?? false) return;
  if (ref.watch(powerSyncDatabaseProvider).value == null) return;
  final int missingCount = await ref.read(
    workoutsMissingMetricsCountProvider.future,
  );
  if (missingCount == 0) return;
  await ref.read(metricsBackfillControllerProvider.notifier).runBackfill();
}
