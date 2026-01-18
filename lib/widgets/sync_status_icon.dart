import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/sync_provider.dart';

/// Sync status icon for navigation bars.
///
/// Shows connection/sync state with appropriate icons:
/// - Green cloud checkmark when synced
/// - Spinner when syncing
/// - Orange cloud when uploading local changes
/// - Gray wifi-off when offline
class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(powerSyncStatusProvider);

    return statusAsync.when(
      data: (status) {
        // Determine state based on PowerSync status
        if (!status.connected) {
          return _buildOffline();
        }

        if (status.downloading || status.uploading) {
          return _buildSyncing(hasLocalChanges: status.uploading);
        }

        if (status.hasSynced == true) {
          return _buildSynced();
        }

        return _buildConnecting();
      },
      loading: () => _buildConnecting(),
      error: (_, __) => _buildOffline(),
    );
  }

  Widget _buildSynced() {
    return const Icon(
      CupertinoIcons.cloud_fill,
      size: 20,
      color: CupertinoColors.systemGreen,
    );
  }

  Widget _buildSyncing({bool hasLocalChanges = false}) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 8),
          if (hasLocalChanges)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemOrange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnecting() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CupertinoActivityIndicator(radius: 8),
    );
  }

  Widget _buildOffline() {
    return const Icon(
      CupertinoIcons.wifi_slash,
      size: 20,
      color: CupertinoColors.systemGrey,
    );
  }
}
