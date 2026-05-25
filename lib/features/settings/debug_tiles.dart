import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
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

class _SyncDebugTileState extends ConsumerState<SyncDebugTile> {
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
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowCountSection(),
          const SizedBox(height: AppSpacing.md),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DebugAction(
          title: 'Refresh counts',
          description:
              'Re-query the local SQLite and Postgres counts shown above. '
              'Use to check whether sync is making progress.',
          onPressed: _refreshCounts,
        ),
        const SizedBox(height: AppSpacing.md),
        _DebugAction(
          title: 'Reconnect to backend',
          description:
              'Drop the current PowerSync session and re-handshake. '
              'Use after switching networks (Wi-Fi <-> cellular, Tailscale '
              'on/off) or if the Connection panel still says offline.',
          onPressed: _reconnecting ? null : _forceReconnect,
          inProgress: _reconnecting,
          accent: AppColors.accentPrimary,
        ),
        const SizedBox(height: AppSpacing.md),
        _DebugAction(
          title: 'Reset local sync data',
          description:
              'Wipe the local SQLite cache and re-download everything from '
              'the server. Use only if local data looks stuck or corrupted. '
              'Pending offline edits will be lost. Destructive.',
          onPressed: _resettingSync ? null : _resetSyncData,
          inProgress: _resettingSync,
          accent: AppColors.error,
        ),
      ],
    );
  }
}

class _DebugAction extends StatelessWidget {
  const _DebugAction({
    required this.title,
    required this.description,
    required this.onPressed,
    this.inProgress = false,
    this.accent,
  });

  final String title;
  final String description;
  final VoidCallback? onPressed;
  final bool inProgress;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final buttonColor = accent ?? AppColors.textColor1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            color: AppColors.backgroundDepth3,
            onPressed: onPressed,
            child: inProgress
                ? const CupertinoActivityIndicator()
                : Text(
                    title,
                    style: AppTypography.body.copyWith(color: buttonColor),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor1,
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
