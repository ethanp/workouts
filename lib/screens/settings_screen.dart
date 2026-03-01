import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/influences_provider.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/providers/template_version_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/screens/influences_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_init.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(healthKitPermissionProvider);
    final exportAsync = ref.watch(healthExportControllerProvider);
    final versionAsync = ref.watch(templateVersionControllerProvider);
    final syncStatus = ref.watch(powerSyncStatusProvider);
    final influencesAsync = ref.watch(activeInfluencesProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _UnitSystemTile(unitSystem: unitSystem, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _TrainingInfluencesTile(influencesAsync: influencesAsync),
            const SizedBox(height: AppSpacing.lg),
            _SyncStatusTile(syncStatus: syncStatus),
            const SizedBox(height: AppSpacing.lg),
            _TemplateVersionTile(versionAsync: versionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _PermissionStatusTile(permissionAsync: permissionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            const _HealthRunImportTile(),
            const SizedBox(height: AppSpacing.lg),
            _HealthDataActions(exportAsync: exportAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            const _SyncDebugTile(),
          ],
        ),
      ),
    );
  }
}

class _UnitSystemTile extends StatelessWidget {
  const _UnitSystemTile({required this.unitSystem, required this.ref});

  final UnitSystem unitSystem;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
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
              CupertinoIcons.arrow_2_squarepath,
              color: AppColors.textColor2,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Units', style: AppTypography.subtitle),
                Text(
                  unitSystem == UnitSystem.imperial ? 'Imperial (mi, mph)' : 'Metric (km, km/h)',
                  style: AppTypography.caption.copyWith(color: AppColors.textColor3),
                ),
              ],
            ),
          ),
          CupertinoSlidingSegmentedControl<UnitSystem>(
            groupValue: unitSystem,
            children: const {
              UnitSystem.imperial: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('mi'),
              ),
              UnitSystem.metric: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('km'),
              ),
            },
            onValueChanged: (value) {
              if (value != null) {
                ref.read(unitSystemProvider.notifier).setUnitSystem(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TrainingInfluencesTile extends StatelessWidget {
  const _TrainingInfluencesTile({required this.influencesAsync});

  final AsyncValue<List<dynamic>> influencesAsync;

  @override
  Widget build(BuildContext context) {
    final activeCount = influencesAsync.value?.length ?? 0;
    final subtitle = activeCount == 0
        ? 'None selected'
        : '$activeCount influence${activeCount == 1 ? '' : 's'} active';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => const InfluencesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
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
                CupertinoIcons.person_2,
                color: AppColors.textColor2,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Training Influences', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textColor3,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.syncStatus});

  final AsyncValue<SyncStatus> syncStatus;

  @override
  Widget build(BuildContext context) {
    final statusLabel = syncStatus.when(
      data: (status) => status.connected ? 'Connected' : 'Offline',
      loading: () => 'Connecting...',
      error: (_, __) => 'Error',
    );

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
          Text('PowerSync Status', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Row(
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
              Text(
                statusLabel,
                style: AppTypography.body.copyWith(color: AppColors.textColor3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateVersionTile extends StatelessWidget {
  const _TemplateVersionTile({required this.versionAsync, required this.ref});

  final AsyncValue<TemplateVersionStatus> versionAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: versionAsync.when(
        data: (status) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Templates', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              status.installed == null
                  ? 'Not initialized (version ${status.current})'
                  : 'Version ${status.installed} installed (current: ${status.current})',
              style: AppTypography.body.copyWith(
                color: status.needsUpdate
                    ? AppColors.warning
                    : AppColors.textColor3,
              ),
            ),
            if (status.needsUpdate) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Templates need to be updated to access new features and fixes.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                onPressed: () => _confirmReseed(context),
                child: const Text(
                  'Update Templates',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Templates', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            const CupertinoActivityIndicator(),
          ],
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Templates', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Error: $error',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReseed(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Update Templates?'),
          message: const Text(
            'This will regenerate all workout templates with the latest version. Any active sessions will not be affected.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                ref.read(templateVersionControllerProvider.notifier).reseed();
              },
              child: const Text('Update Templates'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.permissionAsync,
    required this.ref,
  });

  final AsyncValue<HealthPermissionStatus> permissionAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statusLabel = permissionAsync.when(
      data: (status) => switch (status) {
        HealthPermissionStatus.authorized => 'Authorized',
        HealthPermissionStatus.limited => 'Limited',
        HealthPermissionStatus.denied => 'Denied',
        HealthPermissionStatus.unavailable => 'Unavailable on simulator',
        HealthPermissionStatus.unknown => 'Unknown',
      },
      loading: () => 'Checking…',
      error: (error, _) => 'Error: $error',
    );

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
          Text('Health Permissions', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            statusLabel,
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => ref
                .read(healthKitPermissionProvider.notifier)
                .requestAuthorization(),
            child: const Text('Manage in Health app'),
          ),
        ],
      ),
    );
  }
}

class _HealthDataActions extends StatelessWidget {
  const _HealthDataActions({required this.exportAsync, required this.ref});

  final AsyncValue<HealthExportSummary> exportAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final summary =
        exportAsync.value ??
        const HealthExportSummary(exportedWorkoutUUIDs: []);
    final isLoading = exportAsync.isLoading;
    final errorMessage = exportAsync.whenOrNull(error: (error, _) => '$error');
    final buttonLabel = switch (summary.remainingCount) {
      0 => 'Remove exported workouts from Health',
      final count => 'Remove $count exported workout${count == 1 ? '' : 's'}',
    };

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
          Text('Health Data', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Remove workouts pushed to Apple Health if you want to clear them before the next sync.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            onPressed: isLoading
                ? null
                : () => _confirmDeletion(context, ref, summary.remainingCount),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          if (summary.lastDeletionAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Last removal ${DateFormat('MMM d • HH:mm').format(summary.lastDeletionAt!.toLocal())}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDeletion(BuildContext context, WidgetRef ref, int count) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Remove Health workouts?'),
          message: Text(
            count == 0
                ? 'This removes any workouts we previously exported to Apple Health.'
                : 'This removes $count exported workout${count == 1 ? '' : 's'} from Apple Health using the stored HealthKit identifiers.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                ref
                    .read(healthExportControllerProvider.notifier)
                    .deleteAllExports();
              },
              isDestructiveAction: true,
              child: const Text('Remove from Health'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

class _HealthRunImportTile extends ConsumerWidget {
  const _HealthRunImportTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runImportAsync = ref.watch(runImportControllerProvider);
    final runImportProgress =
        runImportAsync.value ?? const RunImportProgress.idle();
    final isImportingRuns = runImportProgress.inProgress;
    final importErrorMessage = runImportAsync.hasError
        ? '${runImportAsync.error}'
        : null;
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
          Text('Run Import', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Import recent Apple Health runs into your local run database.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: isImportingRuns
                  ? null
                  : () => ref
                        .read(runImportControllerProvider.notifier)
                        .importRecentRuns(),
              child: isImportingRuns
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text(
                      'Import Runs To Local DB',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (isImportingRuns) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Importing runs ${runImportProgress.processedRuns}/${runImportProgress.totalRuns}',
              style: AppTypography.caption.copyWith(color: AppColors.textColor3),
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                height: 6,
                color: AppColors.backgroundDepth3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: runImportProgress.progressFraction.clamp(0.0, 1.0),
                  child: Container(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ] else if (runImportProgress.processedRuns > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Imported ${runImportProgress.processedRuns} runs.',
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
          ],
          if (importErrorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              importErrorMessage,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncDebugSnapshot {
  const _SyncDebugSnapshot({
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

class _SyncDebugTile extends ConsumerStatefulWidget {
  const _SyncDebugTile();

  @override
  ConsumerState<_SyncDebugTile> createState() => _SyncDebugTileState();
}

class _SyncDebugTileState extends ConsumerState<_SyncDebugTile> {
  bool _expanded = false;
  AsyncValue<_SyncDebugSnapshot>? _snapshot;
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

  Future<_SyncDebugSnapshot> _fetchSnapshot() async {
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

    return _SyncDebugSnapshot(
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
        _DebugRow('Local runs', '${snap.localRuns}'),
        _DebugRow(
          'Server runs',
          snap.serverRuns >= 0 ? '${snap.serverRuns}' : 'Unavailable',
        ),
        _DebugRow('CRUD queue', '${snap.totalQueued} total'),
        if (snap.crudQueue.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          ...snap.crudQueue.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: _DebugRow(e.key, '${e.value}'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'As of ${_formatDebugTime(snap.fetchedAt)}',
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

class _DebugRow extends StatelessWidget {
  const _DebugRow(this.label, this.value);

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

String _formatDebugTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}
