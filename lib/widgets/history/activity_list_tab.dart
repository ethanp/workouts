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
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/screens/run_detail_screen.dart';
import 'package:workouts/screens/session_detail_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

class HistoryActivityListTab extends ConsumerWidget {
  const HistoryActivityListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityListProvider);
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;

    return activityAsync.when(
      data: (items) => items.isEmpty
          ? EmptyActivityPlaceholder(
              onImport: dbReady
                  ? () => ref
                      .read(runImportControllerProvider.notifier)
                      .importRecentRuns()
                  : null,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _buildActivityTile(context, ref, items[index]),
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

  Widget _buildActivityTile(
      BuildContext context, WidgetRef ref, ActivityItem item) {
    return switch (item) {
      ActivityRun(:final run) => DismissibleActivityTile(
          key: Key('run-${run.id}'),
          item: item,
          onDelete: () => _deleteRun(ref, run),
          child: RunListTile(run: run),
        ),
      ActivitySession(:final session) => DismissibleActivityTile(
          key: Key('session-${session.id}'),
          item: item,
          onDelete: () => _deleteSession(ref, session),
          child: SessionListTile(session: session),
        ),
    };
  }

  Future<void> _deleteSession(WidgetRef ref, Session session) async {
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.discardSession(session.id);
    ref.invalidate(sessionHistoryProvider);
    final activeSession = ref.read(activeSessionProvider).value;
    if (activeSession?.id == session.id) {
      ref.read(activeSessionProvider.notifier).discard();
    }
  }

  Future<void> _deleteRun(WidgetRef ref, FitnessRun run) async {
    final repository = ref.read(runsRepositoryPowerSyncProvider);
    await repository.deleteRun(run.id);
  }
}

class DismissibleActivityTile extends ConsumerWidget {
  const DismissibleActivityTile({
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
          'This will remove the run from this app. It will stay in Apple Health '
              'and may be re-imported if you run Import again.',
        ),
      ActivitySession() => (
          'Delete Session',
          'Are you sure you want to delete this workout session? '
              'This action cannot be undone.',
        ),
    };

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, title, content),
      background: _deleteBackground(),
      child: child,
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, String title, String content) async {
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
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: CupertinoColors.destructiveRed,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.delete,
              color: CupertinoColors.white, size: 28),
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
    );
  }
}

class EmptyActivityPlaceholder extends StatelessWidget {
  const EmptyActivityPlaceholder({super.key, this.onImport});

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
            'Import runs from Apple Health or complete workout sessions '
            'to see them here.',
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

class RunListTile extends ConsumerWidget {
  const RunListTile({super.key, required this.run});

  final FitnessRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => context.push((_) => RunDetailScreen(run: run)),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Format.dateIso(run.startedAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Format.distance(run.distanceMeters, unitSystem)}  ·  '
                    '${Format.duration(run.durationSeconds)}  ·  '
                    '${Format.pace(run.durationSeconds, run.distanceMeters, unitSystem)}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor1,
                    ),
                  ),
                ],
              ),
            ),
            if (run.routeAvailable)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  CupertinoIcons.map,
                  color: AppColors.accentPrimary,
                  size: 16,
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textColor4,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

}

class SessionListTile extends ConsumerWidget {
  const SessionListTile({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = session.completedAt != null;
    final displayDate = session.completedAt ?? session.startedAt;
    final templatesMapAsync = ref.watch(templatesMapProvider);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _handleTap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color:
                isComplete ? AppColors.borderDepth1 : AppColors.accentPrimary,
            width: isComplete ? 1 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(displayDate, isComplete),
            const SizedBox(height: AppSpacing.sm),
            _templateName(templatesMapAsync),
            const SizedBox(height: AppSpacing.sm),
            _durationLabel(isComplete),
            if (session.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                session.notes!,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!isComplete) _resumeHint(),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(DateTime displayDate, bool isComplete) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(Format.dateRelative(displayDate), style: AppTypography.subtitle),
        _statusBadge(isComplete),
      ],
    );
  }

  Widget _templateName(AsyncValue<Map<String, WorkoutTemplate>> templatesMapAsync) {
    return templatesMapAsync.when(
      data: (templatesMap) {
        final template = templatesMap[session.templateId];
        return Text(
          template?.name ?? 'Unknown Template',
          style: AppTypography.title.copyWith(color: AppColors.textColor1),
        );
      },
      loading: () => const SizedBox(
        height: 24,
        child: CupertinoActivityIndicator(radius: 8),
      ),
      error: (_, __) => Text(
        'Unknown Template',
        style: AppTypography.title.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _durationLabel(bool isComplete) {
    final text = session.duration == null
        ? 'Session started • Tap to resume'
        : 'Completed in ${session.duration!.inMinutes}m '
            '${session.duration!.inSeconds % 60}s';
    return Text(
      text,
      style: AppTypography.body.copyWith(
        color: isComplete ? AppColors.textColor3 : AppColors.accentPrimary,
        fontWeight: isComplete ? FontWeight.w400 : FontWeight.w500,
      ),
    );
  }

  Widget _statusBadge(bool isComplete) {
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

  Widget _resumeHint() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
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
    );
  }


  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    if (session.completedAt == null) {
      await ref.read(activeSessionProvider.notifier).resumeExisting(session);
    } else {
      context.push((_) => SessionDetailScreen(session: session));
    }
  }
}
