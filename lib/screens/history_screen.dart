import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/history_provider.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/screens/session_detail_screen.dart';
import 'package:workouts/services/repositories/session_repository.dart';
import 'package:workouts/theme/app_theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('History'),
        trailing: history.maybeWhen(
          data: (sessions) {
            final inProgressCount = sessions
                .where((s) => s.completedAt == null)
                .length;
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
        ),
      ),
      child: SafeArea(
        child: history.when(
          data: (sessions) => sessions.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemBuilder: (context, index) => _DismissibleSessionTile(
                    session: sessions[index],
                    onDismissed: () async {
                      await _handleDelete(context, ref, sessions[index]);
                    },
                  ),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemCount: sessions.length,
                ),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load history: $error',
              style: AppTypography.body,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
          'Are you sure you want to delete this workout session? This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(sessionRepositoryProvider);
      await repository.discardSession(session.id);
      ref.invalidate(sessionHistoryProvider);
      // Also clear active session if it was the one deleted
      final activeSession = ref.read(activeSessionNotifierProvider).value;
      if (activeSession?.id == session.id) {
        ref.read(activeSessionNotifierProvider.notifier).discard();
      }
    }
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
      final repository = ref.read(sessionRepositoryProvider);
      await repository.discardAllInProgressSessions();
      // Clear active session if it exists
      ref.read(activeSessionNotifierProvider.notifier).discard();
      ref.invalidate(sessionHistoryProvider);
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.clock, size: 64, color: AppColors.textColor4),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No workout history yet',
            style: AppTypography.title.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Complete sessions will appear here for tracking your progress',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textColor4),
          ),
        ],
      ),
    );
  }
}

class _DismissibleSessionTile extends StatelessWidget {
  const _DismissibleSessionTile({
    required this.session,
    required this.onDismissed,
  });

  final Session session;
  final Future<void> Function() onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onDismissed();
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
      child: _SessionTile(session: session),
    );
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
    final sessionDate = DateTime(localDate.year, localDate.month, localDate.day);

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
      await ref
          .read(activeSessionNotifierProvider.notifier)
          .resumeExisting(session);
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => SessionDetailScreen(session: session),
        ),
      );
    }
  }
}
