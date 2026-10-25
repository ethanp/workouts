import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/session_detail/session_detail_screen.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_template.dart';

class const SessionListTile({required final Session session})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = session.isComplete;
    final displayDate = session.completedAt ?? session.startedAt;
    final templatesMapAsync = ref.watch(templatesMapProvider);

    return GestureDetector(
      onTap: () => _resumeOrOpenSession(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceMd,
          vertical: ELayout.spaceSm,
        ),
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(
            color: isComplete ? EColors.border : EColors.accent,
          ),
        ),
        child: Row(
          children: [
            _sessionColorBar(isComplete),
            const SizedBox(width: ELayout.spaceSm),
            Expanded(
              child: _sessionInfo(displayDate, isComplete, templatesMapAsync),
            ),
            if (!isComplete) ...[
              const EStatusChip(
                label: 'In progress',
                tone: EStatusTone.warning,
              ),
              const SizedBox(width: ELayout.spaceXs),
            ],
            const Icon(Icons.chevron_right, color: EColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _sessionColorBar(bool isComplete) => Container(
    width: 3,
    height: 42,
    decoration: BoxDecoration(
      color: isComplete ? EColors.accentGlow : EColors.warning,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sessionInfo(
    DateTime displayDate,
    bool isComplete,
    AsyncValue<Map<String, WorkoutTemplate>> templatesMapAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(displayDate, isComplete, templatesMapAsync),
        const SizedBox(height: 2),
        Text(
          _summaryText(isComplete),
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (session.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: 2),
          Text(
            session.notes!,
            style: EText.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _headerRow(
    DateTime displayDate,
    bool isComplete,
    AsyncValue<Map<String, WorkoutTemplate>> templatesMapAsync,
  ) {
    final templateTitle = templatesMapAsync.maybeWhen(
      data: (templatesMap) =>
          templatesMap[session.templateId]?.name ?? 'Strength Workout',
      orElse: () => 'Strength Workout',
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            templateTitle,
            style: EText.caption.copyWith(
              color: isComplete ? EColors.accentGlow : EColors.warning,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '  ·  ${displayDate.dayKey}',
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
      ],
    );
  }

  String _summaryText(bool isComplete) {
    if (!isComplete) {
      if (session.duration == null) return 'Session started  ·  Tap to resume';
      return '${session.duration!.formattedHms} elapsed  ·  Tap to resume';
    }
    final parts = <String>[
      if (session.duration != null) session.duration!.formattedHms,
      if (session.blocks.isNotEmpty)
        '${session.blocks.length} ${session.blocks.length == 1 ? 'block' : 'blocks'}',
    ];
    final loggedSets = session.blocks.fold<int>(
      0,
      (sum, block) => sum + block.logs.length,
    );
    if (loggedSets > 0) {
      parts.add('$loggedSets ${loggedSets == 1 ? 'set' : 'sets'}');
    }
    if (session.averageHeartRate != null) {
      parts.add('${session.averageHeartRate} bpm');
    }
    return parts.isEmpty ? 'Completed' : parts.join('  ·  ');
  }

  Future<void> _resumeOrOpenSession(BuildContext context, WidgetRef ref) async {
    if (session.isInProgress) {
      await ref.read(activeSessionProvider.notifier).resumeExisting(session);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      );
    }
  }
}
