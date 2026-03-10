import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/cardio_provider.dart';
import 'package:workouts/providers/history_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/history/activity_list_tab.dart';
import 'package:workouts/widgets/history/calendar_tab.dart';
import 'package:workouts/widgets/history/charts_tab.dart';
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
    final sessionHistory = ref.watch(sessionHistoryProvider);
    final importAsync = ref.watch(cardioImportControllerProvider);
    final importProgress =
        importAsync.value ?? const CardioImportProgress.idle();
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
        trailing: _trailing(sessionHistory, isImporting, dbReady),
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

  Widget? _trailing(
    AsyncValue<List<Session>> sessionHistory,
    bool isImporting,
    bool dbReady,
  ) {
    final cancelAll = sessionHistory.maybeWhen(
      data: (sessions) {
        final inProgressCount =
            sessions.where((s) => s.completedAt == null).length;
        if (inProgressCount == 0) return null;
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _cancelAllInProgress(context, inProgressCount),
          child: Text(
            'Cancel All ($inProgressCount)',
            style: AppTypography.body.copyWith(
              color: CupertinoColors.destructiveRed,
            ),
          ),
        );
      },
      orElse: () => null,
    );
    if (cancelAll != null) return cancelAll;

    if (_selectedTab == HistoryTab.list && dbReady && !isImporting) {
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

    return null;
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

  Future<void> _cancelAllInProgress(
      BuildContext context, int count) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cancel All In-Progress Sessions'),
        content: Text(
          'Are you sure you want to cancel all $count in-progress '
          'workout sessions? This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(sessionRepositoryPowerSyncProvider);
      await repository.discardAllInProgressSessions();
      ref.read(activeSessionProvider.notifier).discard();
      ref.invalidate(sessionHistoryProvider);
    }
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
            style:
                AppTypography.subtitle.copyWith(color: AppColors.textColor1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            importProgress.status.isNotEmpty
                ? importProgress.status
                : 'Fetches recent cardio workouts with route and heart rate. '
                    'Only new workouts are added.',
            style:
                AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          if (importProgress.inProgress &&
              importProgress.totalWorkouts > 0) ...[
            const SizedBox(height: AppSpacing.sm),
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
                  widthFactor:
                      importProgress.progressFraction.clamp(0.0, 1.0),
                  child: Container(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
