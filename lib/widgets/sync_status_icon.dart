import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
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
class const SyncStatusIcon() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final description = ref.watch(syncStatusDescriptionProvider);

    return GestureDetector(
      onLongPress: () => _showStatusPopup(context, description),
      child: _icon(syncState),
    );
  }

  Widget _icon(SyncState state) {
    return switch (state) {
      SyncState.synced => const Icon(
        Icons.cloud,
        size: 20,
        color: EColors.success,
      ),
      SyncState.downloading => _syncing(isDownloading: true),
      SyncState.uploading => _syncing(isUploading: true),
      SyncState.connecting => _connecting(),
      SyncState.offline => const Icon(
        Icons.wifi_off,
        size: 20,
        color: EColors.textMuted,
      ),
      SyncState.error => const Icon(
        Icons.error_outline,
        size: 20,
        color: EColors.danger,
      ),
    };
  }

  Widget _syncing({bool isDownloading = false, bool isUploading = false}) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (isUploading)
            const Positioned(
              right: 0,
              bottom: 0,
              child: _Dot(color: EColors.warning),
            ),
          if (isDownloading)
            const Positioned(
              right: 0,
              bottom: 0,
              child: _Dot(color: EColors.accent),
            ),
        ],
      ),
    );
  }

  Widget _connecting() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  void _showStatusPopup(BuildContext context, String description) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync Status'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(description),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class const _Dot({required final Color color}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
