import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/backend/hostname_notifier.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_init.dart';
import 'package:workouts/theme/app_theme.dart';

class CardioImportSnapshot {
  const CardioImportSnapshot({
    required this.localWorkouts,
    required this.importedWorkouts,
    required this.healthKitWorkouts,
    required this.fetchedAt,
  });

  final int localWorkouts;
  final int importedWorkouts;
  final int healthKitWorkouts;
  final DateTime fetchedAt;
}

class CardioImportDebugTile extends ConsumerStatefulWidget {
  const CardioImportDebugTile({super.key});

  @override
  ConsumerState<CardioImportDebugTile> createState() =>
      _CardioImportDebugTileState();
}

class _CardioImportDebugTileState extends ConsumerState<CardioImportDebugTile> {
  bool _expanded = false;
  AsyncValue<CardioImportSnapshot>? _snapshot;

  @override
  Widget build(BuildContext context) {
    ref.listen(cardioImportControllerProvider, (previous, next) {
      final progress = next.value;
      if (progress != null &&
          !progress.inProgress &&
          progress.completedAt != null) {
        if (_expanded && _snapshot != null) _refresh();
      }
    });
    return _buildContent();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _snapshot == null) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _snapshot = const AsyncValue.loading());
    try {
      final snapshot = await _fetchSnapshot();
      if (mounted) setState(() => _snapshot = AsyncValue.data(snapshot));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _snapshot = AsyncValue.error(error, stackTrace));
      }
    }
  }

  Future<CardioImportSnapshot> _fetchSnapshot() async {
    final powerSyncDatabase = await ref.read(powerSyncDatabaseProvider.future);
    final bridge = ref.read(healthKitBridgeProvider);

    final totalRows = await powerSyncDatabase.execute(
      'SELECT COUNT(*) AS cnt FROM cardio_workouts',
    );
    final localWorkouts = totalRows.first['cnt'] as int? ?? 0;

    final importedRows = await powerSyncDatabase.execute(
      'SELECT COUNT(*) AS cnt FROM cardio_workouts WHERE external_workout_id IS NOT NULL',
    );
    final importedWorkouts = importedRows.first['cnt'] as int? ?? 0;

    final healthKitWorkouts = await bridge.countCardioWorkouts();

    return CardioImportSnapshot(
      localWorkouts: localWorkouts,
      importedWorkouts: importedWorkouts,
      healthKitWorkouts: healthKitWorkouts,
      fetchedAt: DateTime.now(),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDepth3,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_down_circle,
                      color: AppColors.textColor2,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Import Debug', style: AppTypography.subtitle),
                  ),
                  Icon(
                    _expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    color: AppColors.textColor3,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: AppColors.borderDepth1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _buildBody(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_snapshot == null || _snapshot!.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_snapshot!.hasError) {
      return Text(
        'Error: ${_snapshot!.error}',
        style: AppTypography.caption.copyWith(color: AppColors.error),
      );
    }

    final importSnapshot = _snapshot!.value!;
    final manualWorkouts =
        importSnapshot.localWorkouts - importSnapshot.importedWorkouts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compares cardio workouts stored locally with those in Apple Health.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
        const SizedBox(height: AppSpacing.md),
        DebugRow('Local workouts (total)', '${importSnapshot.localWorkouts}'),
        DebugRow(
          '  Imported from Health',
          '${importSnapshot.importedWorkouts}',
        ),
        if (manualWorkouts > 0) DebugRow('  Other', '$manualWorkouts'),
        DebugRow(
          'HealthKit cardio workouts',
          importSnapshot.healthKitWorkouts >= 0
              ? '${importSnapshot.healthKitWorkouts}'
              : 'Unavailable',
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'As of ${formatDebugTime(importSnapshot.fetchedAt)}',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            color: AppColors.backgroundDepth3,
            onPressed: _snapshot!.isLoading ? null : _refresh,
            child: Text(
              'Refresh',
              style: AppTypography.body.copyWith(color: AppColors.textColor1),
            ),
          ),
        ),
      ],
    );
  }
}

class SyncDebugTile extends ConsumerStatefulWidget {
  const SyncDebugTile({super.key});

  @override
  ConsumerState<SyncDebugTile> createState() => _SyncDebugTileState();
}

class _HostProbe {
  const _HostProbe({
    required this.label,
    required this.host,
    required this.reachable,
    required this.latency,
    required this.httpStatus,
    required this.error,
  });

  final String label;
  final String host;
  final bool reachable;
  final Duration? latency;
  final int? httpStatus;
  final String? error;

  String get summary {
    if (host.isEmpty) return 'not configured';
    if (reachable) {
      final ms = latency?.inMilliseconds ?? -1;
      final http = httpStatus != null ? ' • HTTP $httpStatus' : '';
      return 'OK ${ms}ms$http';
    }
    return error ?? 'unreachable';
  }
}

class _SyncDebugTileState extends ConsumerState<SyncDebugTile> {
  bool _expanded = false;
  bool _reconnecting = false;
  bool _resettingSync = false;
  bool _probing = false;
  int _localWorkouts = 0;
  int _serverWorkouts = -1;
  DateTime? _countsFetchedAt;
  List<_HostProbe> _probes = const [];
  DateTime? _probedAt;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      if (_countsFetchedAt == null) _refreshCounts();
      if (_probedAt == null) _probeHosts();
    }
  }

  Future<void> _probeHosts() async {
    setState(() => _probing = true);
    final lan = dotenv.env['SERVER_HOST_LAN'] ?? '';
    final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'] ?? '';
    const postgrestPort = 3001;
    final probes = await Future.wait([
      _probeOne('LAN', lan, postgrestPort),
      _probeOne('Tailscale', tailscale, postgrestPort),
    ]);
    if (!mounted) return;
    setState(() {
      _probes = probes;
      _probedAt = DateTime.now();
      _probing = false;
    });
    await ref.read(hostnameProvider.notifier).refineByTcpProbe();
  }

  Future<_HostProbe> _probeOne(String label, String host, int port) async {
    if (host.isEmpty) {
      return _HostProbe(
        label: label,
        host: host,
        reachable: false,
        latency: null,
        httpStatus: null,
        error: 'env var empty',
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      final tcpLatency = stopwatch.elapsed;
      int? httpStatus;
      String? httpError;
      try {
        final response = await http
            .get(Uri.parse('http://$host:$port/'))
            .timeout(const Duration(seconds: 3));
        httpStatus = response.statusCode;
      } catch (error) {
        httpError = error.toString();
      }
      return _HostProbe(
        label: label,
        host: host,
        reachable: true,
        latency: tcpLatency,
        httpStatus: httpStatus,
        error: httpError,
      );
    } catch (error) {
      return _HostProbe(
        label: label,
        host: host,
        reachable: false,
        latency: null,
        httpStatus: null,
        error: error.toString(),
      );
    }
  }

  Future<void> _refreshCounts() async {
    try {
      final powerSyncDatabase = await ref.read(
        powerSyncDatabaseProvider.future,
      );

      final workoutRows = await powerSyncDatabase.execute(
        'SELECT COUNT(*) AS cnt FROM cardio_workouts',
      );
      final localWorkouts = workoutRows.first['cnt'] as int? ?? 0;

      int serverWorkouts = -1;
      try {
        final postgrestUrl = ref.read(postgrestUrlProvider);
        if (postgrestUrl.isNotEmpty) {
          final response = await http
              .get(
                Uri.parse('$postgrestUrl/cardio_workouts?select=id&limit=1'),
                headers: {'Prefer': 'count=exact'},
              )
              .timeout(const Duration(seconds: 5));
          final contentRange = response.headers['content-range'];
          if (contentRange != null) {
            final parts = contentRange.split('/');
            if (parts.length >= 2) {
              serverWorkouts = int.tryParse(parts.last) ?? -1;
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _localWorkouts = localWorkouts;
          _serverWorkouts = serverWorkouts;
          _countsFetchedAt = DateTime.now();
        });
      }
    } catch (_) {}
  }

  Future<void> _forceReconnect() async {
    setState(() => _reconnecting = true);
    try {
      final powerSyncDatabase = await ref.read(
        powerSyncDatabaseProvider.future,
      );
      await connectPowerSync(
        powerSyncDatabase,
        powersyncUrl: ref.read(powersyncUrlProvider),
        postgrestUrl: ref.read(postgrestUrlProvider),
      );
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  Future<void> _resetSyncData() async {
    setState(() => _resettingSync = true);
    try {
      final powerSyncDatabase = await ref.read(
        powerSyncDatabaseProvider.future,
      );
      await powerSyncDatabase.disconnectAndClear();
      await connectPowerSync(
        powerSyncDatabase,
        powersyncUrl: ref.read(powersyncUrlProvider),
        postgrestUrl: ref.read(postgrestUrlProvider),
      );
      if (mounted) _refreshCounts();
    } finally {
      if (mounted) setState(() => _resettingSync = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tileHeader(),
          if (_expanded) ...[
            Container(height: 1, color: AppColors.borderDepth1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _body(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tileHeader() {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundDepth3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                CupertinoIcons.ant,
                color: AppColors.textColor2,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Sync Debug', style: AppTypography.subtitle)),
            Icon(
              _expanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              color: AppColors.textColor3,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _networkSection(),
        const SizedBox(height: AppSpacing.md),
        _rowCountSection(),
        const SizedBox(height: AppSpacing.md),
        _actionButtons(),
      ],
    );
  }

  Widget _networkSection() {
    final activeHost = ref.watch(hostnameProvider);
    final postgrestUrl = ref.watch(postgrestUrlProvider);
    final powersyncUrl = ref.watch(powersyncUrlProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DebugRow('Active host', activeHost),
        DebugRow('PostgREST', postgrestUrl),
        DebugRow('PowerSync', powersyncUrl),
        const SizedBox(height: AppSpacing.xs),
        if (_probing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                CupertinoActivityIndicator(radius: 8),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Probing both candidates...',
                  style: TextStyle(
                    color: AppColors.textColor3,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else if (_probes.isEmpty)
          Text(
            'Not probed yet',
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor4,
            ),
          )
        else ...[
          for (final probe in _probes)
            DebugRow(
              '${probe.label} ${probe.host.isEmpty ? "" : "(${probe.host})"}',
              probe.summary,
            ),
          if (_probedAt != null)
            Text(
              'Probed ${formatDebugTime(_probedAt!)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
              ),
            ),
        ],
      ],
    );
  }

  Widget _rowCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Row counts',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DebugRow('Local workouts', '$_localWorkouts'),
        DebugRow(
          'Postgres workouts (direct)',
          _serverWorkouts >= 0 ? '$_serverWorkouts' : 'Unavailable',
        ),
        if (_countsFetchedAt != null)
          Text(
            'Checked ${formatDebugTime(_countsFetchedAt!)}',
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
          ),
      ],
    );
  }

  Widget _actionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                color: AppColors.backgroundDepth3,
                onPressed: _probing ? null : _probeHosts,
                child: _probing
                    ? const CupertinoActivityIndicator()
                    : Text(
                        'Probe Hosts',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textColor1,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                color: AppColors.backgroundDepth3,
                onPressed: _refreshCounts,
                child: Text(
                  'Refresh Counts',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textColor1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            color: AppColors.backgroundDepth3,
            onPressed: _reconnecting ? null : _forceReconnect,
            child: _reconnecting
                ? const CupertinoActivityIndicator()
                : Text(
                    'Force Re-sync',
                    style: AppTypography.body.copyWith(
                      color: AppColors.accentPrimary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            color: AppColors.backgroundDepth3,
            onPressed: _resettingSync ? null : _resetSyncData,
            child: _resettingSync
                ? const CupertinoActivityIndicator()
                : Text(
                    'Reset Sync Data',
                    style: AppTypography.body.copyWith(color: AppColors.error),
                  ),
          ),
        ),
      ],
    );
  }
}

class DebugRow extends StatelessWidget {
  const DebugRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.caption.copyWith(color: AppColors.textColor1),
          ),
        ],
      ),
    );
  }
}

String formatDebugTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
