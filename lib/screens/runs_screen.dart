import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/screens/run_calendar_screen.dart';
import 'package:workouts/screens/run_detail_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

enum _RunsTab { list, calendar }

class RunsScreen extends ConsumerStatefulWidget {
  const RunsScreen({super.key});

  @override
  ConsumerState<RunsScreen> createState() => _RunsScreenState();
}

class _RunsScreenState extends ConsumerState<RunsScreen> {
  _RunsTab _selectedTab = _RunsTab.list;

  @override
  Widget build(BuildContext context) {
    final importAsync = ref.watch(runImportControllerProvider);
    final importProgress = importAsync.value ?? const RunImportProgress.idle();
    final isImporting = importProgress.inProgress;
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(isImporting: isImporting, dbReady: dbReady),
      child: SafeArea(
        child: Column(
          children: [
            if (isImporting)
              _ImportProgressBanner(importProgress: importProgress),
            _segmentedControl(),
            Expanded(child: _tabContent()),
          ],
        ),
      ),
    );
  }

  CupertinoNavigationBar _navigationBar({
    required bool isImporting,
    required bool dbReady,
  }) {
    return CupertinoNavigationBar(
      leading: const SyncStatusIcon(),
      middle: const Text('Runs'),
      trailing: _selectedTab == _RunsTab.list
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: dbReady && !isImporting
                  ? () => ref
                        .read(runImportControllerProvider.notifier)
                        .importRecentRuns()
                  : null,
              child: isImporting
                  ? const CupertinoActivityIndicator()
                  : const Icon(CupertinoIcons.arrow_down_circle),
            )
          : null,
    );
  }

  Widget _segmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: CupertinoSlidingSegmentedControl<_RunsTab>(
        groupValue: _selectedTab,
        onValueChanged: (tab) {
          if (tab != null) setState(() => _selectedTab = tab);
        },
        children: const {
          _RunsTab.list: Text('List'),
          _RunsTab.calendar: Text('Calendar'),
        },
      ),
    );
  }

  Widget _tabContent() {
    return switch (_selectedTab) {
      _RunsTab.list => _RunsListTab(ref: ref),
      _RunsTab.calendar => const RunCalendarScreen(),
    };
  }
}

class _RunsListTab extends StatelessWidget {
  const _RunsListTab({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(runsStreamProvider);
    return runsAsync.when(
      data: (runs) => _runsListView(runs),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load runs: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _runsListView(List<FitnessRun> runs) {
    return runs.isEmpty
        ? _EmptyRunsState(
            onImport: () => ref
                .read(runImportControllerProvider.notifier)
                .importRecentRuns(),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: runs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _RunTile(run: runs[index]),
          );
  }
}

class _ImportProgressBanner extends StatelessWidget {
  const _ImportProgressBanner({required this.importProgress});

  final RunImportProgress importProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.backgroundDepth2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          progressLabel(),
          const SizedBox(height: AppSpacing.xs),
          progressBar(),
        ],
      ),
    );
  }

  Widget progressLabel() {
    return Text(
      'Importing runs ${importProgress.processedRuns}/${importProgress.totalRuns}',
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    );
  }

  Widget progressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        height: 6,
        color: AppColors.backgroundDepth3,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: importProgress.progressFraction.clamp(0.0, 1.0),
          child: Container(color: AppColors.accentPrimary),
        ),
      ),
    );
  }
}

class _EmptyRunsState extends StatelessWidget {
  const _EmptyRunsState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: 56,
              color: AppColors.textColor4,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No runs imported yet', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Import your recent runs from Apple Health to view route and heart rate details.',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: onImport,
              child: const Text('Import Runs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunTile extends ConsumerWidget {
  const _RunTile({required this.run});

  final FitnessRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => context.push((_) => RunDetailScreen(run: run)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Format.dateIso(run.startedAt), style: AppTypography.subtitle),
                if (run.routeAvailable)
                  Text(
                    'Route',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Format.distance(run.distanceMeters, unitSystem),
              style: AppTypography.title.copyWith(color: AppColors.textColor1),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${Format.duration(run.durationSeconds)}  ·  ${Format.pace(run.durationSeconds, run.distanceMeters, unitSystem)}',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
            ),
          ],
        ),
      ),
    );
  }

}
