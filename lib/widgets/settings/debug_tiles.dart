import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_init.dart';
import 'package:workouts/theme/app_theme.dart';

class RunImportSnapshot {
  const RunImportSnapshot({
    required this.localRuns,
    required this.importedRuns,
    required this.healthKitRuns,
    required this.fetchedAt,
  });

  final int localRuns;
  final int importedRuns;
  final int healthKitRuns;
  final DateTime fetchedAt;
}

class RunImportDebugTile extends ConsumerStatefulWidget {
  const RunImportDebugTile({super.key});

  @override
  ConsumerState<RunImportDebugTile> createState() =>
      _RunImportDebugTileState();
}

class _RunImportDebugTileState extends ConsumerState<RunImportDebugTile> {
  bool _expanded = false;
  AsyncValue<RunImportSnapshot>? _snapshot;

  @override
  Widget build(BuildContext context) {
    ref.listen(runImportControllerProvider, (previous, next) {
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

  Future<RunImportSnapshot> _fetchSnapshot() async {
    final db = await ref.read(powerSyncDatabaseProvider.future);
    final bridge = ref.read(healthKitBridgeProvider);

    final totalRows = await db.execute('SELECT COUNT(*) AS cnt FROM runs');
    final localRuns = totalRows.first['cnt'] as int? ?? 0;

    final importedRows = await db.execute(
      'SELECT COUNT(*) AS cnt FROM runs WHERE external_workout_id IS NOT NULL',
    );
    final importedRuns = importedRows.first['cnt'] as int? ?? 0;

    final healthKitRuns = await bridge.countRunningWorkouts();

    return RunImportSnapshot(
      localRuns: localRuns,
      importedRuns: importedRuns,
      healthKitRuns: healthKitRuns,
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
    final manualRuns = snap.localRuns - snap.importedRuns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compares runs stored locally with running workouts in Apple Health.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
        const SizedBox(height: AppSpacing.md),
        DebugRow('Local runs (total)', '${snap.localRuns}'),
        DebugRow('  Imported from Health', '${snap.importedRuns}'),
        if (manualRuns > 0) DebugRow('  Other', '$manualRuns'),
        DebugRow(
          'HealthKit running workouts',
          snap.healthKitRuns >= 0 ? '${snap.healthKitRuns}' : 'Unavailable',
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

class SyncDebugSnapshot {
  const SyncDebugSnapshot({
    required this.localRuns,
    required this.serverRuns,
    required this.crudQueue,
    required this.fetchedAt,
  });

  final int localRuns;
  final int serverRuns;
  final Map<String, int> crudQueue;
  final DateTime fetchedAt;

  int get totalQueued => crudQueue.values.fold(0, (a, b) => a + b);
}

class SyncDebugTile extends ConsumerStatefulWidget {
  const SyncDebugTile({super.key});

  @override
  ConsumerState<SyncDebugTile> createState() => _SyncDebugTileState();
}

class _SyncDebugTileState extends ConsumerState<SyncDebugTile> {
  bool _expanded = false;
  AsyncValue<SyncDebugSnapshot>? _snapshot;
  bool _reconnecting = false;

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

  Future<SyncDebugSnapshot> _fetchSnapshot() async {
    final db = await ref.read(powerSyncDatabaseProvider.future);

    final localRunRows = await db.execute('SELECT COUNT(*) AS cnt FROM runs');
    final localRuns = localRunRows.first['cnt'] as int? ?? 0;

    final crudRows = await db.execute(
      "SELECT json_extract(data, '\$.type') AS tbl, COUNT(*) AS cnt "
      'FROM ps_crud GROUP BY tbl',
    );
    final crudQueue = {
      for (final row in crudRows)
        (row['tbl'] as String? ?? 'unknown'): row['cnt'] as int? ?? 0,
    };

    int serverRuns = -1;
    try {
      final postgrestUrl = dotenv.env['POSTGREST_URL'] ?? '';
      if (postgrestUrl.isNotEmpty) {
        final response = await http
            .get(
              Uri.parse('$postgrestUrl/runs?select=id&limit=1'),
              headers: {'Prefer': 'count=exact'},
            )
            .timeout(const Duration(seconds: 5));
        final contentRange = response.headers['content-range'];
        if (contentRange != null) {
          final parts = contentRange.split('/');
          if (parts.length >= 2) {
            serverRuns = int.tryParse(parts.last) ?? -1;
          }
        }
      }
    } catch (_) {}

    return SyncDebugSnapshot(
      localRuns: localRuns,
      serverRuns: serverRuns,
      crudQueue: crudQueue,
      fetchedAt: DateTime.now(),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PowerSync: compares data on this device with the cloud server. '
          '(Not Apple Health import.)',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
        const SizedBox(height: AppSpacing.md),
        DebugRow('Runs on this device', '${snap.localRuns}'),
        DebugRow(
          'Runs on server',
          snap.serverRuns >= 0 ? '${snap.serverRuns}' : 'Unavailable',
        ),
        DebugRow(
          'Pending uploads',
          snap.totalQueued > 0
              ? '${snap.totalQueued} (local changes waiting to sync)'
              : '0',
        ),
        if (snap.crudQueue.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          ...snap.crudQueue.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: DebugRow(e.key, '${e.value}'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'As of ${formatDebugTime(snap.fetchedAt)}',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                color: AppColors.backgroundDepth3,
                onPressed: _snapshot!.isLoading ? null : _refresh,
                child: Text(
                  'Refresh',
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
