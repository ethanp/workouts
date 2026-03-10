import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/providers/cardio_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
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
    } catch (e, st) {
      if (mounted) setState(() => _snapshot = AsyncValue.error(e, st));
    }
  }

  Future<CardioImportSnapshot> _fetchSnapshot() async {
    final db = await ref.read(powerSyncDatabaseProvider.future);
    final bridge = ref.read(healthKitBridgeProvider);

    final totalRows =
        await db.execute('SELECT COUNT(*) AS cnt FROM cardio_workouts');
    final localWorkouts = totalRows.first['cnt'] as int? ?? 0;

    final importedRows = await db.execute(
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

    final snap = _snapshot!.value!;
    final manualWorkouts = snap.localWorkouts - snap.importedWorkouts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compares cardio workouts stored locally with those in Apple Health.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
        const SizedBox(height: AppSpacing.md),
        DebugRow('Local workouts (total)', '${snap.localWorkouts}'),
        DebugRow('  Imported from Health', '${snap.importedWorkouts}'),
        if (manualWorkouts > 0) DebugRow('  Other', '$manualWorkouts'),
        DebugRow(
          'HealthKit cardio workouts',
          snap.healthKitWorkouts >= 0
              ? '${snap.healthKitWorkouts}'
              : 'Unavailable',
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'As of ${formatDebugTime(snap.fetchedAt)}',
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
  Map<String, int> _crudQueue = {};
  int _localWorkouts = 0;
  int _serverWorkouts = -1;
  DateTime? _crudFetchedAt;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _crudFetchedAt == null) _refreshCrud();
  }

  Future<void> _refreshCrud() async {
    try {
      final db = await ref.read(powerSyncDatabaseProvider.future);

      final crudRows = await db.execute(
        "SELECT json_extract(data, '\$.type') AS tbl, COUNT(*) AS cnt "
        'FROM ps_crud GROUP BY tbl',
      );
      final crudQueue = {
        for (final row in crudRows)
          (row['tbl'] as String? ?? 'unknown'): row['cnt'] as int? ?? 0,
      };

      final workoutRows =
          await db.execute('SELECT COUNT(*) AS cnt FROM cardio_workouts');
      final localWorkouts = workoutRows.first['cnt'] as int? ?? 0;

      int serverWorkouts = -1;
      try {
        final postgrestUrl = dotenv.env['POSTGREST_URL'] ?? '';
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
          _crudQueue = crudQueue;
          _localWorkouts = localWorkouts;
          _serverWorkouts = serverWorkouts;
          _crudFetchedAt = DateTime.now();
        });
      }
    } catch (_) {}
  }

  Future<void> _forceReconnect() async {
    setState(() => _reconnecting = true);
    try {
      final db = await ref.read(powerSyncDatabaseProvider.future);
      await reconnectPowerSync(db);
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(powerSyncStatusProvider);

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
              child: _body(syncStatus),
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
            Expanded(
              child: Text('Sync Debug', style: AppTypography.subtitle),
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
    );
  }

  Widget _body(AsyncValue<SyncStatus> syncStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _connectionSection(syncStatus),
        const SizedBox(height: AppSpacing.md),
        _crudQueueSection(),
        const SizedBox(height: AppSpacing.md),
        _rowCountSection(),
        const SizedBox(height: AppSpacing.md),
        _actionButtons(),
      ],
    );
  }

  Widget _connectionSection(AsyncValue<SyncStatus> syncStatus) {
    return syncStatus.when(
      data: (status) {
        final connectionLabel =
            status.connected ? '🟢 Connected' : '🔴 Disconnected';

        String? activityLabel;
        if (status.downloading) {
          final progress = status.downloadProgress;
          activityLabel = progress != null
              ? '⬇️ Downloading ${progress.downloadedOperations}/${progress.totalOperations}'
              : '⬇️ Downloading...';
        } else if (status.uploading) {
          activityLabel = '⬆️ Uploading...';
        }

        final lastSynced = status.lastSyncedAt;
        final lastSyncLabel = lastSynced != null
            ? formatDebugTime(lastSynced)
            : 'Never';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DebugRow('Connection', connectionLabel),
            if (activityLabel != null)
              DebugRow('Activity', activityLabel),
            DebugRow('Initial sync done', '${status.hasSynced ?? false}'),
            DebugRow('Last synced', lastSyncLabel),
          ],
        );
      },
      loading: () => const DebugRow('Connection', 'Loading...'),
      error: (error, _) => DebugRow('Connection', 'Error: $error'),
    );
  }

  Widget _crudQueueSection() {
    final totalQueued = _crudQueue.values.fold(0, (sum, count) => sum + count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DebugRow(
          'Pending uploads',
          totalQueued > 0 ? '$totalQueued ops' : '0',
        ),
        if (_crudQueue.isNotEmpty)
          ..._crudQueue.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: DebugRow(entry.key, '${entry.value}'),
            ),
          ),
        if (_crudFetchedAt != null)
          Text(
            'Queue checked ${formatDebugTime(_crudFetchedAt!)}',
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
          ),
      ],
    );
  }

  Widget _rowCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DebugRow('Local workouts', '$_localWorkouts'),
        DebugRow(
          'Server workouts',
          _serverWorkouts >= 0 ? '$_serverWorkouts' : 'Unavailable',
        ),
      ],
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            color: AppColors.backgroundDepth3,
            onPressed: _refreshCrud,
            child: Text(
              'Refresh Queue',
              style:
                  AppTypography.body.copyWith(color: AppColors.textColor1),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
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

String formatDebugTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}
