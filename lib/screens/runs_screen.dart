import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/screens/run_detail_screen.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(runsStreamProvider);
    final importAsync = ref.watch(runImportControllerProvider);
    final importProgress = importAsync.value ?? const RunImportProgress.idle();
    final isImporting = importProgress.inProgress;

    return CupertinoPageScaffold(
      navigationBar: navigationBar(isImporting, ref),
      child: SafeArea(
        child: Column(
          children: [
            if (isImporting)
              _ImportProgressBanner(importProgress: importProgress),
            Expanded(
              child: runsAsync.when(
                data: (runs) => runsListView(runs, ref),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Unable to load runs: $error',
                    style: AppTypography.body.copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  CupertinoNavigationBar navigationBar(bool isImporting, WidgetRef ref) {
    return CupertinoNavigationBar(
      leading: const SyncStatusIcon(),
      middle: const Text('Runs'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: isImporting
            ? null
            : () => ref
                  .read(runImportControllerProvider.notifier)
                  .importRecentRuns(),
        child: isImporting
            ? const CupertinoActivityIndicator()
            : const Icon(CupertinoIcons.arrow_down_circle),
      ),
    );
  }

  StatelessWidget runsListView(List<FitnessRun> runs, WidgetRef ref) {
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

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final FitnessRun run;

  @override
  Widget build(BuildContext context) {
    final distanceKm = run.distanceMeters / 1000;
    final pacePerKilometerSeconds = run.distanceMeters > 0
        ? run.durationSeconds / (run.distanceMeters / 1000)
        : 0.0;

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
                Text(
                  _formatRunDate(run.startedAt),
                  style: AppTypography.subtitle,
                ),
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
              '${distanceKm.toStringAsFixed(2)} km',
              style: AppTypography.title.copyWith(color: AppColors.textColor1),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_formatDuration(run.durationSeconds)}  ·  ${_formatPace(pacePerKilometerSeconds)}',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRunDate(DateTime startedAt) {
    final localDate = startedAt.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int durationSeconds) {
    final duration = Duration(seconds: durationSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatPace(double pacePerKilometerSeconds) {
    if (pacePerKilometerSeconds <= 0) {
      return '--:-- /km';
    }
    final roundedSeconds = pacePerKilometerSeconds.round();
    final minutes = roundedSeconds ~/ 60;
    final seconds = roundedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }
}
