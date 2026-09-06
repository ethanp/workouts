import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/session_detail/session_detail_screen.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/utils/run_formatting.dart';

class const SessionListTile({required final Session session})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = session.isComplete;
    final displayDate = session.completedAt ?? session.startedAt;
    final templatesMapAsync = ref.watch(templatesMapProvider);

    return InkWell(
      onTap: () => _resumeOrOpenSession(context, ref),
      child: Container(
        padding: const EdgeInsets.all(ELayout.spaceLg),
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusXl),
          border: Border.all(
            color: isComplete
                ? EColors.border
                : EColors.accent,
            width: isComplete ? 1 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(displayDate, isComplete),
            const SizedBox(height: ELayout.spaceSm),
            _templateName(templatesMapAsync),
            const SizedBox(height: ELayout.spaceSm),
            _durationLabel(isComplete),
            if (session.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: ELayout.spaceSm),
              Text(
                session.notes!,
                style: EText.caption,
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
        Text(Format.dateRelative(displayDate), style: EText.section),
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
          style: EText.title.copyWith(color: EColors.textPrimary),
        );
      },
      loading: () => const SizedBox(
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => Text(
        'Unknown Template',
        style: EText.title.copyWith(color: EColors.textTertiary),
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
      style: EText.body.medium.copyWith(
        color: isComplete ? EColors.textTertiary : EColors.accent,
        fontWeight: isComplete ? FontWeight.w400 : FontWeight.w500,
      ),
    );
  }

  Widget _statusBadge(bool isComplete) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: isComplete ? EColors.success : EColors.accent,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        isComplete ? 'Completed' : 'In Progress',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _resumeHint() {
    return Padding(
      padding: const EdgeInsets.only(top: ELayout.spaceMd),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_outline,
            color: EColors.accent,
            size: 20,
          ),
          const SizedBox(width: ELayout.spaceXs),
          Text(
            'Tap to resume workout',
            style: EText.caption.copyWith(
              color: EColors.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeOrOpenSession(BuildContext context, WidgetRef ref) async {
    if (session.isInProgress) {
      await ref.read(activeSessionProvider.notifier).resumeExisting(session);
    } else {
      context.push(SessionDetailScreen(session: session));
    }
  }
}
