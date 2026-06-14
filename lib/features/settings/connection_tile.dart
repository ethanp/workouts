import 'package:ethan_sync/ethan_sync.dart' show hostResolverProvider, pendingUploadCountProvider, syncStatusProvider;
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/backend/host_probes_notifier.dart';
import 'package:workouts/theme/app_theme.dart';

/// Single tile that surfaces all user-relevant connection state: status,
/// pending uploads, and per-candidate host reachability (LAN, Tailscale).
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
      ref.read(hostProbesProvider.notifier).probe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final description = ref.watch(syncStatusDescriptionProvider);
    final pendingAsync = ref.watch(pendingUploadCountProvider);
    final activeHost = ref.watch(hostResolverProvider);
    final probes = ref.watch(hostProbesProvider);
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
          _titleRow(probes.isProbing),
          const SizedBox(height: AppSpacing.sm),
          _statusRow(isConnected, description),
          const SizedBox(height: AppSpacing.sm),
          ..._hostRows(activeHost, probes),
          ..._switchRouteSection(activeHost),
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
        : () => ref.read(hostProbesProvider.notifier).probe(),
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

  /// Always renders one row per declared candidate (LAN, Tailscale) so the
  /// list is stable across probe states. While the first probe is in flight
  /// we synthesize "Probing..." rows from `.env` rather than empty space.
  List<Widget> _hostRows(String activeHost, HostProbesState probes) {
    final lanHost = dotenv.env['SERVER_HOST_LAN'] ?? '';
    final tailscaleHost = dotenv.env['SERVER_HOST_TAILSCALE'] ?? '';
    return [
      _hostRow(
        label: 'Home LAN',
        host: lanHost,
        probe: _probeFor('LAN', probes.probes),
        isActive: activeHost == lanHost,
        isProbing: probes.isProbing && probes.probes.isEmpty,
      ),
      const SizedBox(height: AppSpacing.xs),
      _hostRow(
        label: 'Tailscale',
        host: tailscaleHost,
        probe: _probeFor('Tailscale', probes.probes),
        isActive: activeHost == tailscaleHost,
        isProbing: probes.isProbing && probes.probes.isEmpty,
      ),
    ];
  }

  HostProbe? _probeFor(String label, List<HostProbe> probes) {
    for (final probe in probes) {
      if (probe.label == label) return probe;
    }
    return null;
  }

  Widget _hostRow({
    required String label,
    required String host,
    required HostProbe? probe,
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
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '\u00B7 active',
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

  /// Pair of [label, host] for the route that is currently NOT active, or
  /// null when there's no alternative to switch to (single candidate
  /// configured, both env vars equal, or active host doesn't match either).
  ({String label, String host})? _otherRoute(String activeHost) {
    final lan = dotenv.env['SERVER_HOST_LAN'] ?? '';
    final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'] ?? '';
    if (lan.isEmpty || tailscale.isEmpty || lan == tailscale) return null;
    if (activeHost == lan) return (label: 'Tailscale', host: tailscale);
    if (activeHost == tailscale) return (label: 'Home LAN', host: lan);
    return null;
  }

  List<Widget> _switchRouteSection(String activeHost) {
    final other = _otherRoute(activeHost);
    if (other == null) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          color: AppColors.backgroundDepth3,
          onPressed: () =>
              ref.read(hostResolverProvider.notifier).setHost(other.host),
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

  IconData _statusIcon({required HostProbe? probe, required bool isProbing}) {
    if (isProbing || probe == null) return CupertinoIcons.circle;
    if (probe.reachable) return CupertinoIcons.checkmark_circle_fill;
    return CupertinoIcons.xmark_circle_fill;
  }

  Color _statusColor({required HostProbe? probe, required bool isProbing}) {
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
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ),
      ],
    ),
  );
}
