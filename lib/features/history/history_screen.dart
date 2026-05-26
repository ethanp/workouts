import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/history/activity_list/history_activity_list_tab.dart';
import 'package:workouts/features/history/calendar_tab.dart';
import 'package:workouts/features/history/charts/history_charts_tab.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

enum HistoryTab { charts, list, calendar }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryTab _selectedTab = HistoryTab.charts;

  @override
  Widget build(BuildContext context) {
    final importAsync = ref.watch(cardioImportControllerProvider);
    // Riverpod 3.x's state-error transition auto-applies copyWithPrevious,
    // so `importAsync.value` returns the prior loading data after a failure.
    // Drop back to idle on error so this banner doesn't stay stuck on
    // "Requesting Apple Health access…" forever — the global error banner
    // and the Settings Apple Health card surface the actual failure.
    final importProgress = (importAsync.hasError ? null : importAsync.value) ??
        const CardioImportProgress.idle();
    final isImporting = importProgress.inProgress;
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;
    final syncState = ref.watch(syncStateProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SyncStatusIcon(),
            const SizedBox(width: 4),
            Text(syncState.name.titleCase, style: AppTypography.caption),
          ],
        ),
        middle: const Text('History'),
        trailing: _trailing(isImporting, dbReady),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (isImporting || importProgress.completedAt != null)
              ImportProgressBanner(importProgress: importProgress),
            _segmentedControl(),
            Expanded(child: _tabContent()),
          ],
        ),
      ),
    );
  }

  Widget? _trailing(bool isImporting, bool dbReady) {
    if (!dbReady || isImporting) return null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => ref
          .read(cardioImportControllerProvider.notifier)
          .importRecentWorkouts(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.arrow_down_circle, size: 22),
          const SizedBox(width: 4),
          Text('Import', style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _segmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: CupertinoSlidingSegmentedControl<HistoryTab>(
        groupValue: _selectedTab,
        onValueChanged: (tab) {
          if (tab != null) setState(() => _selectedTab = tab);
        },
        children: const {
          HistoryTab.charts: Text('Charts'),
          HistoryTab.list: Text('List'),
          HistoryTab.calendar: Text('Calendar'),
        },
      ),
    );
  }

  Widget _tabContent() {
    return switch (_selectedTab) {
      HistoryTab.charts => const HistoryChartsTab(),
      HistoryTab.list => const HistoryActivityListTab(),
      HistoryTab.calendar => const HistoryCalendarTab(),
    };
  }

}

class ImportProgressBanner extends StatelessWidget {
  const ImportProgressBanner({super.key, required this.importProgress});

  final CardioImportProgress importProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.backgroundDepth2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import from Apple Health',
            style: AppTypography.subtitle.copyWith(color: AppColors.textColor1),
          ),
          const SizedBox(height: AppSpacing.xs),
          _statusText(),
          if (importProgress.inProgress &&
              importProgress.totalWorkouts > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _progressBar(),
          ],
        ],
      ),
    );
  }

  Widget _statusText() => Text(
    importProgress.status.isNotEmpty
        ? importProgress.status
        : 'Fetches recent cardio workouts with route and heart rate. '
              'Only new workouts are added.',
    style: AppTypography.caption.copyWith(color: AppColors.textColor3),
  );

  Widget _progressBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${importProgress.processedWorkouts}/${importProgress.totalWorkouts}',
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor2,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
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
      ),
    ],
  );
}
