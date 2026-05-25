import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/backend/hostname_notifier.dart';
import 'package:workouts/theme/app_theme.dart';

/// Single tile that surfaces all user-relevant connection state: status,
/// last synced timestamp, pending uploads, and which backend host is in use.
class ConnectionTile extends ConsumerWidget {
  const ConnectionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(powerSyncStatusProvider);
    final description = ref.watch(syncStatusDescriptionProvider);
    final pendingAsync = ref.watch(pendingUploadCountProvider);
    final activeHost = ref.watch(hostnameProvider);
    final isConnected = syncStatus.value?.connected ?? false;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connection', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          _statusRow(isConnected, description),
          const SizedBox(height: AppSpacing.xs),
          _detailRow(
            CupertinoIcons.globe,
            _hostLabel(activeHost),
            _hostSubLabel(activeHost),
          ),
          if ((pendingAsync.value ?? 0) > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _detailRow(
              CupertinoIcons.arrow_up_circle,
              '${pendingAsync.value} pending upload${pendingAsync.value == 1 ? '' : 's'}',
              null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(bool isConnected, String description) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isConnected ? AppColors.success : AppColors.warning,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          description,
          style: AppTypography.body.copyWith(color: AppColors.textColor2),
        ),
      ),
    ],
  );

  Widget _detailRow(IconData icon, String label, String? subLabel) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textColor4),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ),
        if (subLabel != null)
          Text(
            subLabel,
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
          ),
      ],
    ),
  );

  String _hostLabel(String activeHost) {
    final lan = dotenv.env['SERVER_HOST_LAN'];
    final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'];
    if (activeHost == lan) return 'Home LAN';
    if (activeHost == tailscale) return 'Tailscale';
    return activeHost;
  }

  String? _hostSubLabel(String activeHost) {
    final lan = dotenv.env['SERVER_HOST_LAN'];
    final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'];
    if (activeHost == lan || activeHost == tailscale) return activeHost;
    return null;
  }
}
