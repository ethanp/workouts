import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/history/activity_list/history_activity_list_tab.dart';
import 'package:workouts/features/history/calendar_tab.dart';
import 'package:workouts/features/history/charts/history_charts_tab.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

enum HistoryTab() {
  charts,
  list,
  calendar,
}

class const HistoryScreen() extends ConsumerStatefulWidget {
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState() extends ConsumerState<HistoryScreen> {
  HistoryTab _selectedTab = HistoryTab.charts;

  @override
  Widget build(BuildContext context) {
    final importAsync = ref.watch(cardioImportControllerProvider);
    // Riverpod 3.x's state-error transition auto-applies copyWithPrevious,
    // so `importAsync.value` returns the prior loading data after a failure.
    // Drop back to idle on error so this banner doesn't stay stuck on
    // "Requesting Apple Health access…" forever — the global error banner
    // and the Settings Apple Health card surface the actual failure.
    final importProgress =
        (importAsync.hasError ? null : importAsync.value) ??
        const CardioImportProgress.idle();
    final isImporting = importProgress.inProgress;
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(
        title: 'History',
        automaticallyImplyLeading: false,
        leading: _syncStatus(syncState),
        actions: [if (dbReady && !isImporting) _importAction()],
      ),
      body: SafeArea(
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

  Widget _syncStatus(SyncState syncState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SyncStatusIcon(),
        const SizedBox(width: 4),
        Text(syncState.name.titleCase, style: EText.caption),
      ],
    );
  }

  Widget _importAction() {
    return TextButton.icon(
      onPressed: () => ref
          .read(cardioImportControllerProvider.notifier)
          .importRecentWorkouts(),
      icon: const Icon(Icons.download, size: 20),
      label: const Text('Import'),
    );
  }

  Widget _segmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceSm,
      ),
      child: SegmentedButton<HistoryTab>(
        segments: const [
          ButtonSegment(value: HistoryTab.charts, label: Text('Charts')),
          ButtonSegment(value: HistoryTab.list, label: Text('List')),
          ButtonSegment(value: HistoryTab.calendar, label: Text('Calendar')),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (tabs) =>
            setState(() => _selectedTab = tabs.single),
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

class const ImportProgressBanner({
  required final CardioImportProgress importProgress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      color: EColors.backgroundLift,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import from Apple Health',
            style: EText.section.copyWith(color: EColors.textPrimary),
          ),
          const SizedBox(height: ELayout.spaceXs),
          _statusText(),
          if (importProgress.inProgress &&
              importProgress.totalWorkouts > 0) ...[
            const SizedBox(height: ELayout.spaceSm),
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
    style: EText.caption.copyWith(color: EColors.textTertiary),
  );

  Widget _progressBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${importProgress.processedWorkouts}/${importProgress.totalWorkouts}',
        style: EText.caption.copyWith(
          color: EColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: ELayout.spaceXs),
      ClipRRect(
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        child: Container(
          height: 6,
          color: EColors.surface,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: importProgress.progressFraction.clamp(0.0, 1.0),
            child: Container(color: EColors.accent),
          ),
        ),
      ),
    ],
  );
}
