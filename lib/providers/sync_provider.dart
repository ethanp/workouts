import 'package:ethan_sync/ethan_sync.dart' as sync;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

/// Live PowerSync status, pending-upload count, and offline flag come from
/// ethan_sync. The workouts-specific [SyncState] and description providers
/// below adapt that status into the shapes the UI renders.

/// Detailed sync state for UI display.
enum SyncState { connecting, downloading, uploading, synced, offline, error }

final syncStateProvider = Provider<SyncState>((ref) {
  return ref.watch(sync.syncStatusProvider).when(
        data: (status) {
          if (!status.connected) return SyncState.offline;
          if (status.downloading) return SyncState.downloading;
          if (status.uploading) return SyncState.uploading;
          if (status.hasSynced == true) return SyncState.synced;
          return SyncState.connecting;
        },
        loading: () => SyncState.connecting,
        error: (_, __) => SyncState.error,
      );
});

/// Human-readable sync status description.
final syncStatusDescriptionProvider = Provider<String>((ref) {
  return ref.watch(sync.syncStatusProvider).when(
        data: _describeStatus,
        loading: () => 'Connecting...',
        error: (error, _) => 'Error: $error',
      );
});

String _describeStatus(SyncStatus status) {
  if (!status.connected) return 'Offline';
  if (status.downloading) {
    final progress = status.downloadProgress;
    if (progress != null) {
      return 'Downloading ${progress.downloadedOperations}/${progress.totalOperations}';
    }
    return 'Downloading...';
  }
  if (status.uploading) return 'Uploading changes...';
  if (status.hasSynced == true) {
    final lastSyncedAt = status.lastSyncedAt;
    return lastSyncedAt != null ? 'Synced ${_relativeTime(lastSyncedAt)}' : 'Synced';
  }
  return 'Connecting...';
}

String _relativeTime(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
