import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/activity_provider.dart';
import 'package:workouts/providers/history_provider.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/screens/run_detail_screen.dart';
import 'package:workouts/screens/session_detail_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/activity_calendar.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

enum _HistoryTab { list, calendar }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryTab _selectedTab = _HistoryTab.list;

  @override
  Widget build(BuildContext context) {
    final sessionHistory = ref.watch(sessionHistoryProvider);
    final importAsync = ref.watch(runImportControllerProvider);
    final importProgress = importAsync.value ?? const RunImportProgress.idle();
    final isImporting = importProgress.inProgress;
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;

    final trailing = _buildTrailing(
      sessionHistory: sessionHistory,
      isImporting: isImporting,
      dbReady: dbReady,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: const SyncStatusIcon(),
        middle: const Text('History'),
        trailing: trailing,
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (isImporting) _ImportProgressBanner(importProgress: importProgress),
            _segmentedControl(),
            Expanded(child: _tabContent()),
          ],
        ),
      ),
    );
  }

  Widget? _buildTrailing({
    required AsyncValue<List<Session>> sessionHistory,
    required bool isImporting,
    required bool dbReady,
  }) {
    final cancelAll = sessionHistory.maybeWhen(
      data: (sessions) {
        final inProgressCount =
            sessions.where((s) => s.completedAt == null).length;
        if (inProgressCount == 0) return null;
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () =>
              _handleCancelAllInProgress(context, ref, inProgressCount),
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
    if (_selectedTab == _HistoryTab.list && dbReady && !isImporting) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () =>
            ref.read(runImportControllerProvider.notifier).importRecentRuns(),
        child: const Icon(CupertinoIcons.arrow_down_circle),
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
      child: CupertinoSlidingSegmentedControl<_HistoryTab>(
        groupValue: _selectedTab,
        onValueChanged: (tab) {
          if (tab != null) setState(() => _selectedTab = tab);
        },
        children: const {
          _HistoryTab.list: Text('List'),
          _HistoryTab.calendar: Text('Calendar'),
        },
      ),
    );
  }

  Widget _tabContent() {
    return switch (_selectedTab) {
      _HistoryTab.list => const _ActivityListTab(),
      _HistoryTab.calendar => const _ActivityCalendarTab(),
    };
  }

  Future<void> _handleCancelAllInProgress(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cancel All In-Progress Sessions'),
        content: Text(
          'Are you sure you want to cancel all $count in-progress workout sessions? This action cannot be undone.',
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
          Text(
            'Importing runs ${importProgress.processedRuns}/${importProgress.totalRuns}',
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
                widthFactor: importProgress.progressFraction.clamp(0.0, 1.0),
                child: Container(color: AppColors.accentPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityListTab extends ConsumerWidget {
  const _ActivityListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityListProvider);
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;

    return activityAsync.when(
      data: (items) => items.isEmpty
          ? _EmptyActivityState(
              onImport: dbReady
                  ? () => ref
                      .read(runImportControllerProvider.notifier)
                      .importRecentRuns()
                  : null,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                return switch (item) {
                  ActivityRun(:final run) => _DismissibleActivityTile(
                      key: Key('run-${run.id}'),
                      item: item,
                      onDelete: () => _handleDeleteRun(ref, run),
                      child: _RunTile(run: run),
                    ),
                  ActivitySession(:final session) => _DismissibleActivityTile(
                      key: Key('session-${session.id}'),
                      item: item,
                      onDelete: () => _handleDeleteSession(ref, session),
                      child: _SessionTile(session: session),
                    ),
                };
              },
            ),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load activity: $error',
          style: AppTypography.body,
        ),
      ),
    );
  }

  Future<void> _handleDeleteSession(WidgetRef ref, Session session) async {
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.discardSession(session.id);
    ref.invalidate(sessionHistoryProvider);
    final activeSession = ref.read(activeSessionProvider).value;
    if (activeSession?.id == session.id) {
      ref.read(activeSessionProvider.notifier).discard();
    }
  }

  Future<void> _handleDeleteRun(WidgetRef ref, FitnessRun run) async {
    final repository = ref.read(runsRepositoryPowerSyncProvider);
    await repository.deleteRun(run.id);
  }
}

class _DismissibleActivityTile extends ConsumerWidget {
  const _DismissibleActivityTile({
    required super.key,
    required this.item,
    required this.onDelete,
    required this.child,
  });

  final ActivityItem item;
  final Future<void> Function() onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, content) = switch (item) {
      ActivityRun() => (
          'Delete Run',
          'Are you sure you want to delete this run? This action cannot be undone.',
        ),
      ActivitySession() => (
          'Delete Session',
          'Are you sure you want to delete this workout session? This action cannot be undone.',
        ),
    };

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await onDelete();
          return true;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.delete, color: CupertinoColors.white, size: 28),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Delete',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState({this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.clock, size: 64, color: AppColors.textColor4),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No activity yet',
            style: AppTypography.title.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Import runs from Apple Health or complete workout sessions to see them here.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textColor4),
          ),
          if (onImport != null) ...[
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: onImport,
              child: const Text('Import Runs'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCalendarTab extends ConsumerWidget {
  const _ActivityCalendarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activityMetricsBackfillProvider);

    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return calendarAsync.when(
      data: (days) {
        final activityData = {for (final day in days) day.date: day};
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ActivityCalendar(
              activityData: activityData,
              unitSystem: unitSystem,
              onDateTap: (date) => _showDayDetail(context, ref, date),
            ),
          ],
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load calendar: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context, WidgetRef ref, DateTime date) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _DayDetailSheet(date: date),
    );
  }
}

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activityForDateProvider(date));
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoActionSheet(
      title: Text(_formatDate(date)),
      message: itemsAsync.when(
        data: (items) => items.isEmpty
            ? const Text('No activity on this day')
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: _ItemList(items: items, unitSystem: unitSystem),
                ),
              ),
        loading: () => const CupertinoActivityIndicator(),
        error: (_, __) => const Text('Unable to load'),
      ),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.unitSystem,
  });

  final List<ActivityItem> items;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        return switch (item) {
          ActivityRun(:final run) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).pop();
                context.push((_) => RunDetailScreen(run: run));
              },
              child: _RunRow(run: run, unitSystem: unitSystem),
            ),
          ActivitySession(:final session) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).pop();
                context.push((_) => SessionDetailScreen(session: session));
              },
              child: _SessionRow(session: session),
            ),
        };
      }).toList(),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run, required this.unitSystem});

  final FitnessRun run;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(run.durationSeconds);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatDistance(run.distanceMeters, unitSystem),
                style: AppTypography.body,
              ),
            ],
          ),
          Text(duration, style: AppTypography.caption),
        ],
      ),
    );
  }

  String _formatDuration(int durationSeconds) {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesMapAsync = ref.watch(templatesMapProvider);
    final duration = session.duration != null
        ? '${session.duration!.inMinutes}m'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.clock, size: 20),
              const SizedBox(width: AppSpacing.sm),
              templatesMapAsync.when(
                data: (templatesMap) {
                  final template = templatesMap[session.templateId];
                  return Text(
                    template?.name ?? 'Session',
                    style: AppTypography.body,
                  );
                },
                loading: () => const Text('…', style: AppTypography.body),
                error: (_, __) => const Text('Session', style: AppTypography.body),
              ),
            ],
          ),
          Text(duration, style: AppTypography.caption),
        ],
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
                Text(_formatRunDate(run.startedAt), style: AppTypography.subtitle),
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
              formatDistance(run.distanceMeters, unitSystem),
              style: AppTypography.title.copyWith(color: AppColors.textColor1),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_formatDuration(run.durationSeconds)}  ·  ${formatPace(run.durationSeconds, run.distanceMeters, unitSystem)}',
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
    final d = Duration(seconds: durationSeconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = session.completedAt != null;
    final displayDate = session.completedAt ?? session.startedAt;
    final templatesMapAsync = ref.watch(templatesMapProvider);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _handleSessionTap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isComplete
                ? AppColors.borderDepth1
                : AppColors.accentPrimary,
            width: isComplete ? 1 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(displayDate), style: AppTypography.subtitle),
                _buildStatusBadge(isComplete),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            templatesMapAsync.when(
              data: (templatesMap) {
                final template = templatesMap[session.templateId];
                return Text(
                  template?.name ?? 'Unknown Template',
                  style: AppTypography.title.copyWith(
                    color: AppColors.textColor1,
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 24,
                child: CupertinoActivityIndicator(radius: 8),
              ),
              error: (_, __) => Text(
                'Unknown Template',
                style: AppTypography.title.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _getDurationText(session.duration),
              style: AppTypography.body.copyWith(
                color: isComplete
                    ? AppColors.textColor3
                    : AppColors.accentPrimary,
                fontWeight: isComplete ? FontWeight.w400 : FontWeight.w500,
              ),
            ),
            if (session.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                session.notes!,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!isComplete) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.play_circle,
                    color: AppColors.accentPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Tap to resume workout',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isComplete) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.success : AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isComplete ? 'Completed' : 'In Progress',
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${localDate.month.toString().padLeft(2, '0')}/${localDate.day.toString().padLeft(2, '0')}/${localDate.year}';
    }
  }

  String _getDurationText(Duration? duration) {
    if (duration == null) {
      return 'Session started • Tap to resume';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return 'Completed in ${minutes}m ${seconds}s';
  }

  Future<void> _handleSessionTap(BuildContext context, WidgetRef ref) async {
    if (session.completedAt == null) {
      await ref.read(activeSessionProvider.notifier).resumeExisting(session);
    } else {
      context.push((_) => SessionDetailScreen(session: session));
    }
  }
}
