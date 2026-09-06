import 'dart:async';
import 'package:ethan_ui/ethan_ui.dart';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/sync_provider.dart';

/// Surfaces sync status, pending uploads, and per-candidate host reachability.
class const ConnectionTile() extends ConsumerStatefulWidget {
  @override
  ConsumerState<ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState() extends ConsumerState<ConnectionTile> {
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
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(health.isProbing),
          const SizedBox(height: ELayout.spaceSm),
          _statusRow(
            isConnected: isConnected,
            isConnecting: isConnecting,
            description: description,
          ),
          const SizedBox(height: ELayout.spaceSm),
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
            const SizedBox(height: ELayout.spaceXs),
            _pendingRow(pendingAsync.value!),
          ],
        ],
      ),
    );
  }

  Widget _titleRow(bool isProbing) => Row(
    children: [
      Expanded(child: Text('Connection', style: EText.section)),
      _probeButton(isProbing),
    ],
  );

  Widget _probeButton(bool isProbing) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: EColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceMd,
        vertical: ELayout.spaceXs,
      ),
      minimumSize: Size.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: ELayout.borderRadiusSm,
      ),
    ),
    onPressed: isProbing
        ? null
        : () => ref.read(syncEnsureProvider).ensureConnected(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isProbing)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(
            Icons.wifi_tethering,
            size: 14,
            color: EColors.accent,
          ),
        const SizedBox(width: ELayout.spaceXs),
        Text(
          'Probe',
          style: EText.caption.copyWith(
            color: EColors.accent,
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
              ? EColors.success
              : (isConnecting ? EColors.accent : EColors.warning),
        ),
      ),
      const SizedBox(width: ELayout.spaceSm),
      Expanded(
        child: Text(
          description,
          style: EText.body.medium.copyWith(color: EColors.textSecondary),
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
      if (index > 0) rows.add(const SizedBox(height: ELayout.spaceXs));
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
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: EText.caption.copyWith(
                        color: EColors.textTertiary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: ELayout.spaceXs),
                      Text(
                        '\u00B7 selected',
                        style: EText.caption.copyWith(
                          color: EColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  host.isEmpty ? '(not configured)' : host,
                  style: EText.caption.copyWith(
                    color: EColors.textMuted,
                  ),
                ),
                if (probe != null && !isProbing) ...[
                  const SizedBox(height: 1),
                  Text(
                    probe.summary,
                    style: EText.caption.copyWith(color: statusColor),
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
      return (label: hostResolution.labels[host] ?? host, host: host);
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
      const SizedBox(height: ELayout.spaceSm),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: EColors.surface,
            padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
          ),
          onPressed: () => ref.read(syncEnsureProvider).switchHost(other.host),
          child: Text(
            'Switch to ${other.label}',
            style: EText.body.medium.copyWith(
              color: EColors.accent,
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
    if (isProbing || probe == null) return Icons.circle_outlined;
    if (probe.reachable) return Icons.check_circle;
    return Icons.cancel;
  }

  Color _statusColor({
    required HostCandidateHealth? probe,
    required bool isProbing,
  }) {
    if (isProbing || probe == null) return EColors.textMuted;
    if (probe.reachable) return EColors.success;
    return EColors.warning;
  }

  Widget _pendingRow(int pending) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        const Icon(
          Icons.arrow_circle_up,
          size: 14,
          color: EColors.textMuted,
        ),
        const SizedBox(width: ELayout.spaceSm),
        Expanded(
          child: Text(
            '$pending pending upload${pending == 1 ? '' : 's'}',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
        ),
      ],
    ),
  );
}
