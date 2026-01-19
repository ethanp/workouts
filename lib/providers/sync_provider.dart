import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/powersync_database_provider.dart';

export 'package:powersync/powersync.dart' show SyncStatus;

part 'sync_provider.g.dart';

final _log = Logger('Sync');

@riverpod
Stream<SyncStatus> powerSyncStatus(Ref ref) async* {
  // Wait for database to be ready
  final db = await ref.watch(powerSyncDatabaseProvider.future);

  SyncStatus? lastStatus;

  // Emit current status immediately
  final initial = db.currentStatus;
  _logSyncStatus(initial, lastStatus);
  lastStatus = initial;
  yield initial;

  // Then emit status changes
  await for (final status in db.statusStream) {
    _logSyncStatus(status, lastStatus);
    lastStatus = status;
    yield status;
  }
}

void _logSyncStatus(SyncStatus status, SyncStatus? previous) {
  final changes = <String>[
    ..._connectionChanges(status, previous),
    ..._downloadStateChanges(status, previous),
    ..._uploadStateChanges(status, previous),
    ..._initialSyncChanges(status, previous),
  ];

  if (changes.isNotEmpty) {
    _log.info(changes.join(' | '));
  }

  _logDownloadProgress(status, previous);
  _logLastSyncTime(status, previous);
}

List<String> _connectionChanges(SyncStatus status, SyncStatus? previous) {
  if (previous == null || previous.connected != status.connected) {
    return [status.connected ? '🟢 Connected' : '🔴 Disconnected'];
  }
  return [];
}

List<String> _downloadStateChanges(SyncStatus status, SyncStatus? previous) {
  if (previous?.downloading == status.downloading) return [];

  if (status.downloading) {
    final progress = status.downloadProgress;
    if (progress != null) {
      return [
        '⬇️ Downloading: ${progress.downloadedOperations}/${progress.totalOperations} ops',
      ];
    }
    return ['⬇️ Downloading...'];
  }

  if (previous?.downloading == true) {
    return ['⬇️ Download complete'];
  }

  return [];
}

List<String> _uploadStateChanges(SyncStatus status, SyncStatus? previous) {
  if (previous?.uploading == status.uploading) return [];

  if (status.uploading) {
    return ['⬆️ Uploading local changes...'];
  }

  if (previous?.uploading == true) {
    return ['⬆️ Upload complete'];
  }

  return [];
}

List<String> _initialSyncChanges(SyncStatus status, SyncStatus? previous) {
  if (previous?.hasSynced != true && status.hasSynced == true) {
    return ['✅ Initial sync complete'];
  }
  return [];
}

void _logDownloadProgress(SyncStatus status, SyncStatus? previous) {
  if (!status.downloading || status.downloadProgress == null) return;

  final progress = status.downloadProgress!;
  final prevProgress = previous?.downloadProgress;

  final hasNewProgress = prevProgress == null ||
      progress.downloadedOperations != prevProgress.downloadedOperations;
  final isSignificant = progress.downloadedOperations % 10 == 0 ||
      progress.downloadedOperations == progress.totalOperations;

  if (hasNewProgress && isSignificant) {
    developer.log(
      'Download progress: ${progress.downloadedOperations}/${progress.totalOperations} '
      '(${(progress.downloadedFraction * 100).toStringAsFixed(0)}%)',
      name: 'Sync',
    );
  }
}

void _logLastSyncTime(SyncStatus status, SyncStatus? previous) {
  if (status.lastSyncedAt != previous?.lastSyncedAt &&
      status.lastSyncedAt != null) {
    _log.fine('Last synced: ${status.lastSyncedAt}');
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

/// Detailed sync state for UI display
enum SyncState {
  connecting,
  downloading,
  uploading,
  synced,
  offline,
  error,
}

@riverpod
SyncState syncState(Ref ref) {
  final statusAsync = ref.watch(powerSyncStatusProvider);
  return statusAsync.when(
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
}

/// Human-readable sync status description
@riverpod
String syncStatusDescription(Ref ref) {
  final statusAsync = ref.watch(powerSyncStatusProvider);
  return statusAsync.when(
    data: (status) {
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
        final lastSync = status.lastSyncedAt;
        if (lastSync != null) {
          return 'Synced ${_formatRelativeTime(lastSync)}';
        }
        return 'Synced';
      }
      return 'Connecting...';
    },
    loading: () => 'Connecting...',
    error: (e, _) => 'Error: $e',
  );
}

String _formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
