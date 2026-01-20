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
///
/// Long press shows detailed sync status.
class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final description = ref.watch(syncStatusDescriptionProvider);

    return GestureDetector(
      onLongPress: () => _showStatusPopup(context, description),
      child: _buildIcon(syncState),
    );
  }

  Widget _buildIcon(SyncState state) {
    return switch (state) {
      SyncState.synced => const Icon(
        CupertinoIcons.cloud_fill,
        size: 20,
        color: CupertinoColors.systemGreen,
      ),
      SyncState.downloading => _buildSyncing(isDownloading: true),
      SyncState.uploading => _buildSyncing(isUploading: true),
      SyncState.connecting => _buildConnecting(),
      SyncState.offline => const Icon(
        CupertinoIcons.wifi_slash,
        size: 20,
        color: CupertinoColors.systemGrey,
      ),
      SyncState.error => const Icon(
        CupertinoIcons.exclamationmark_circle,
        size: 20,
        color: CupertinoColors.systemRed,
      ),
    };
  }

  Widget _buildSyncing({bool isDownloading = false, bool isUploading = false}) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 8),
          if (isUploading)
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
          if (isDownloading)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBlue,
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

  void _showStatusPopup(BuildContext context, String description) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sync Status'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(description),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
