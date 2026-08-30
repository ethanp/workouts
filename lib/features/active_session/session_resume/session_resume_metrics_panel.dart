import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/session_resume/block_navigation_hint_row.dart';
import 'package:workouts/features/active_session/session_resume/session_resume_action_row.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';

class const SessionResumeMetricsPanel({
  required final Session session,
  required final List<HeartRateSample> heartRateSamples,
  required final bool watchConnected,
  required final VoidCallback? onPreviousBlock,
  required final VoidCallback? onNextBlock,
  required final VoidCallback onTogglePause,
  required final VoidCallback onAddNote,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlockNavigationHintRow(
          onPrevious: onPreviousBlock,
          onNext: onNextBlock,
        ),
        if (watchConnected) ...[
          const SizedBox(height: AppSpacing.sm),
          CardioMetricsCard(samples: heartRateSamples),
        ],
        const SizedBox(height: AppSpacing.sm),
        SessionResumeActionRow(
          isPaused: session.isPaused,
          watchConnected: watchConnected,
          onTogglePause: onTogglePause,
          onAddNote: onAddNote,
        ),
      ],
    ),
  );
}
