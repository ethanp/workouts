import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/session_resume/block_navigation_hint_row.dart';
import 'package:workouts/features/active_session/session_resume/session_resume_action_row.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';

class SessionResumeMetricsPanel extends StatelessWidget {
  const SessionResumeMetricsPanel({
    super.key,
    required this.session,
    required this.heartRateSamples,
    required this.watchConnected,
    required this.onPreviousBlock,
    required this.onNextBlock,
    required this.onTogglePause,
    required this.onAddNote,
  });

  final Session session;
  final List<HeartRateSample> heartRateSamples;
  final bool watchConnected;
  final VoidCallback? onPreviousBlock;
  final VoidCallback? onNextBlock;
  final VoidCallback onTogglePause;
  final VoidCallback onAddNote;

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
