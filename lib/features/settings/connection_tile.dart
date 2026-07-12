import 'dart:async';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/theme/app_theme.dart';

/// Surfaces sync status, pending uploads, and per-candidate host reachability.
class ConnectionTile extends ConsumerStatefulWidget {
  const ConnectionTile({super.key});

  @override
  ConsumerState<ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState extends ConsumerState<ConnectionTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(syncEnsureProvider).ensureConnected());
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final description = ref.watch(syncStatusDescriptionProvider);
    final pendingAsync = ref.watch(pendingUploadCountProvider);
    final activeHost = ref.watch(hostResolverProvider);
    final health = ref.watch(hostHealthProvider);
    final hostResolution = ref.watch(syncConfigProvider).hostResolution;
    final isConnected = syncStatus.value?.connected ?? false;
    final isConnecting = syncStatus.value?.connecting ?? false;

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
          _titleRow(health.isProbing),
          const SizedBox(height: AppSpacing.sm),
          _statusRow(
            isConnected: isConnected,
            isConnecting: isConnecting,
            description: description,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._hostRows(
            activeHost: activeHost,
            health: health,
            hostResolution: hostResolution,
          ),
          ..._switchRouteSection(
            activeHost: activeHost,
            hostResolution: hostResolution,
          ),
          if ((pendingAsync.value ?? 0) > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _pendingRow(pendingAsync.value!),
          ],
        ],
      ),
    );
  }

  Widget _titleRow(bool isProbing) => Row(
    children: [
      Expanded(child: Text('Connection', style: AppTypography.subtitle)),
      _probeButton(isProbing),
    ],
  );

  Widget _probeButton(bool isProbing) => CupertinoButton(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    minimumSize: const Size(0, 0),
    color: AppColors.backgroundDepth3,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    onPressed: isProbing
        ? null
        : () => ref.read(syncEnsureProvider).ensureConnected(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isProbing)
          const CupertinoActivityIndicator(radius: 7)
        else
          const Icon(
            CupertinoIcons.dot_radiowaves_left_right,
            size: 14,
            color: AppColors.accentPrimary,
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Probe',
          style: AppTypography.caption.copyWith(
            color: AppColors.accentPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _statusRow({
    required bool isConnected,
    required bool isConnecting,
    required String description,
  }) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isConnected
              ? AppColors.success
              : (isConnecting ? AppColors.accentPrimary : AppColors.warning),
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

  List<Widget> _hostRows({
    required String activeHost,
    required HostHealthState health,
    required HostResolutionSettings hostResolution,
  }) {
    final rows = <Widget>[];
    for (var index = 0; index < hostResolution.candidates.length; index++) {
      if (index > 0) rows.add(const SizedBox(height: AppSpacing.xs));
      final host = hostResolution.candidates[index];
      final label = hostResolution.labels[host] ?? host;
      rows.add(
        _hostRow(
          label: label,
          host: host,
          probe: health.forHost(host),
          isActive: activeHost == host,
          isProbing: health.isProbing && health.candidates.isEmpty,
        ),
      );
    }
    return rows;
  }

  Widget _hostRow({
    required String label,
    required String host,
    required HostCandidateHealth? probe,
    required bool isActive,
    required bool isProbing,
  }) {
    final statusIcon = _statusIcon(probe: probe, isProbing: isProbing);
    final statusColor = _statusColor(probe: probe, isProbing: isProbing);
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textColor3,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '\u00B7 selected',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  host.isEmpty ? '(not configured)' : host,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textColor4,
                  ),
                ),
                if (probe != null && !isProbing) ...[
                  const SizedBox(height: 1),
                  Text(
                    probe.summary,
                    style: AppTypography.caption.copyWith(color: statusColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String label, String host})? _otherRoute({
    required String activeHost,
    required HostResolutionSettings hostResolution,
  }) {
    if (hostResolution.candidates.length < 2) return null;
    for (final host in hostResolution.candidates) {
      if (host == activeHost) continue;
      return (
        label: hostResolution.labels[host] ?? host,
        host: host,
      );
    }
    return null;
  }

  List<Widget> _switchRouteSection({
    required String activeHost,
    required HostResolutionSettings hostResolution,
  }) {
    final other = _otherRoute(
      activeHost: activeHost,
      hostResolution: hostResolution,
    );
    if (other == null) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          color: AppColors.backgroundDepth3,
          onPressed: () => ref.read(syncEnsureProvider).switchHost(other.host),
          child: Text(
            'Switch to ${other.label}',
            style: AppTypography.body.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }

  IconData _statusIcon({
    required HostCandidateHealth? probe,
    required bool isProbing,
  }) {
    if (isProbing || probe == null) return CupertinoIcons.circle;
    if (probe.reachable) return CupertinoIcons.checkmark_circle_fill;
    return CupertinoIcons.xmark_circle_fill;
  }

  Color _statusColor({
    required HostCandidateHealth? probe,
    required bool isProbing,
  }) {
    if (isProbing || probe == null) return AppColors.textColor4;
    if (probe.reachable) return AppColors.success;
    return AppColors.warning;
  }

  Widget _pendingRow(int pending) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        const Icon(
          CupertinoIcons.arrow_up_circle,
          size: 14,
          color: AppColors.textColor4,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '$pending pending upload${pending == 1 ? '' : 's'}',
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
          ),
        ),
      ],
    ),
  );
}
