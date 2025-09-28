import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/history_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('History')),
      child: SafeArea(
        child: history.when(
          data: (sessions) => sessions.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemBuilder: (context, index) =>
                      _SessionTile(session: sessions[index]),
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

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = session.completedAt != null;
    final displayDate = session.completedAt ?? session.startedAt;

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
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
      // Resume existing incomplete session
      await ref
          .read(activeSessionNotifierProvider.notifier)
          .resumeExisting(session);
    } else {
      // Show completed session details (could navigate to detail screen)
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Session Complete'),
          content: Text(
            'Workout completed on ${_formatDate(session.completedAt!)}\n'
            'Duration: ${_getDurationText(session.duration)}\n\n'
            '${session.notes ?? "No notes"}',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}
