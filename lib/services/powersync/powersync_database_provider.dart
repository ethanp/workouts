import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

/// The open, connected local PowerSync database that repositories query.
///
/// Watching it activates ethan_sync's [syncConnectionProvider] (open + initial
/// connect + reconnect when the host changes) and returns the underlying
/// [PowerSyncDatabase]. The DB is opened once; connection is managed by the
/// shared connection controller.
final powerSyncDatabaseProvider = FutureProvider<PowerSyncDatabase>((ref) async {
  await ref.watch(syncConnectionProvider.future);
  final manager = await ref.watch(powerSyncDatabaseManagerProvider.future);
  return manager.database;
});
