import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/powersync_database_provider.dart';

export 'package:powersync/powersync.dart' show SyncStatus;

part 'sync_provider.g.dart';

@riverpod
Stream<SyncStatus> powerSyncStatus(Ref ref) async* {
  final dbAsync = ref.watch(powerSyncDatabaseProvider);
  final db = dbAsync.valueOrNull;
  if (db == null) return;

  // Emit current status immediately
  yield db.currentStatus;

  // Then emit status changes
  await for (final status in db.statusStream) {
    yield status;
  }
}

@riverpod
bool isOffline(Ref ref) {
  final statusAsync = ref.watch(powerSyncStatusProvider);
  return statusAsync.maybeWhen(
    data: (status) => !status.connected,
    orElse: () => true, // Default to offline while loading
  );
}
