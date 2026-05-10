import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/session_detail/session_detail_screen.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

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
            color: isComplete
                ? AppColors.borderDepth1
                : AppColors.accentPrimary,
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

  Widget _templateName(
    AsyncValue<Map<String, WorkoutTemplate>> templatesMapAsync,
  ) {
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
      context.push(SessionDetailScreen(session: session));
    }
  }
}
