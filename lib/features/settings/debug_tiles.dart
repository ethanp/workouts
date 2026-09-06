import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

class const CardioImportSnapshot({
  required final int localWorkouts,
  required final int importedWorkouts,
  required final int healthKitWorkouts,
  required final DateTime fetchedAt,
});

class const CardioImportDebugTile() extends ConsumerStatefulWidget {
  @override
  ConsumerState<CardioImportDebugTile> createState() =>
      _CardioImportDebugTileState();
}

class _CardioImportDebugTileState()
    extends ConsumerState<CardioImportDebugTile> {
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
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(ELayout.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: EColors.surface,
                      borderRadius: BorderRadius.circular(ELayout.radiusSm),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: EColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: ELayout.spaceMd),
                  Expanded(
                    child: Text('Import Debug', style: EText.section),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: EColors.textTertiary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: EColors.border),
            Padding(
              padding: const EdgeInsets.all(ELayout.spaceMd),
              child: _buildBody(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_snapshot == null || _snapshot!.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_snapshot!.hasError) {
      return Text(
        'Error: ${_snapshot!.error}',
        style: EText.caption.copyWith(color: EColors.danger),
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
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
        const SizedBox(height: ELayout.spaceMd),
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
        const SizedBox(height: ELayout.spaceXs),
        Text(
          'As of ${formatDebugTime(importSnapshot.fetchedAt)}',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
        const SizedBox(height: ELayout.spaceMd),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EColors.surface,
              padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
            ),
            onPressed: _snapshot!.isLoading ? null : _refresh,
            child: Text(
              'Refresh',
              style: EText.body.medium.copyWith(color: EColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class const SyncDebugTile() extends ConsumerStatefulWidget {
  @override
  ConsumerState<SyncDebugTile> createState() => _SyncDebugTileState();
}

class _SyncDebugTileState() extends ConsumerState<SyncDebugTile> {
  bool _expanded = false;
  bool _reconnecting = false;
  bool _resettingSync = false;
  int _localWorkouts = 0;
  int _serverWorkouts = -1;
  DateTime? _countsFetchedAt;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _countsFetchedAt == null) _refreshCounts();
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
      await ref.read(syncEnsureProvider).reconnect();
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
      await ref.read(syncEnsureProvider).reconnect(reason: 'after reset');
      if (mounted) _refreshCounts();
    } finally {
      if (mounted) setState(() => _resettingSync = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tileHeader(),
          if (_expanded) ...[
            Container(height: 1, color: EColors.border),
            Padding(
              padding: const EdgeInsets.all(ELayout.spaceMd),
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
        padding: const EdgeInsets.all(ELayout.spaceMd),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: EColors.surface,
                borderRadius: BorderRadius.circular(ELayout.radiusSm),
              ),
              child: const Icon(
                Icons.bug_report,
                color: EColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: ELayout.spaceMd),
            Expanded(child: Text('Sync Debug', style: EText.section)),
            Icon(
              _expanded
                  ? Icons.expand_less
                  : Icons.expand_more,
              color: EColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowCountSection(),
          const SizedBox(height: ELayout.spaceMd),
          _actionButtons(),
        ],
      ),
    );
  }

  Widget _rowCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Row counts',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ELayout.spaceXs),
        DebugRow('Local workouts', '$_localWorkouts'),
        DebugRow(
          'Postgres workouts (direct)',
          _serverWorkouts >= 0 ? '$_serverWorkouts' : 'Unavailable',
        ),
        if (_countsFetchedAt != null)
          Text(
            'Checked ${formatDebugTime(_countsFetchedAt!)}',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
      ],
    );
  }

  Widget _actionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DebugAction(
          title: 'Refresh counts',
          description:
              'Re-query the local SQLite and Postgres counts shown above. '
              'Use to check whether sync is making progress.',
          onActivated: _refreshCounts,
        ),
        const SizedBox(height: ELayout.spaceMd),
        _DebugAction(
          title: 'Reconnect to backend',
          description:
              'Drop the current PowerSync session and re-handshake. '
              'Use after switching networks (Wi-Fi <-> cellular, Tailscale '
              'on/off) or if the Connection panel still says offline.',
          onActivated: _reconnecting ? null : _forceReconnect,
          inProgress: _reconnecting,
          accent: EColors.accent,
        ),
        const SizedBox(height: ELayout.spaceMd),
        _DebugAction(
          title: 'Reset local sync data',
          description:
              'Wipe the local SQLite cache and re-download everything from '
              'the server. Use only if local data looks stuck or corrupted. '
              'Pending offline edits will be lost. Destructive.',
          onActivated: _resettingSync ? null : _resetSyncData,
          inProgress: _resettingSync,
          accent: EColors.danger,
        ),
      ],
    );
  }
}

class const _DebugAction({
  required final String title,
  required final String description,
  required final VoidCallback? onActivated,
  final bool inProgress = false,
  final Color? accent,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final buttonColor = accent ?? EColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
        const SizedBox(height: ELayout.spaceXs),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EColors.surface,
              padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
            ),
            onPressed: onActivated,
            child: inProgress
                ? const CircularProgressIndicator()
                : Text(
                    title,
                    style: EText.body.medium.copyWith(color: buttonColor),
                  ),
          ),
        ),
      ],
    );
  }
}

class const DebugRow(final String label, final String value)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: EText.caption.copyWith(
                color: EColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: EText.caption.copyWith(
                color: EColors.textPrimary,
              ),
            ),
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
