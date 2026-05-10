import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/session_indicators.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionResumeActionRow extends StatelessWidget {
  const SessionResumeActionRow({
    super.key,
    required this.isPaused,
    required this.watchConnected,
    required this.onTogglePause,
    required this.onAddNote,
  });

  final bool isPaused;
  final bool watchConnected;
  final VoidCallback onTogglePause;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _pauseButton(),
        if (isPaused) ...[const SizedBox(width: AppSpacing.md), _pausedPill()],
        const SizedBox(width: AppSpacing.md),
        _addNoteButton(),
        if (!isPaused) ...[
          const Spacer(),
          WatchConnectionIndicator(isConnected: watchConnected),
        ],
      ],
    );
  }

  Widget _pauseButton() {
    return CupertinoButton.filled(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      onPressed: onTogglePause,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
            color: CupertinoColors.white,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isPaused ? 'Resume' : 'Pause',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pausedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning),
      ),
      child: Text(
        'Paused',
        style: AppTypography.caption.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _addNoteButton() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onPressed: onAddNote,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.pencil_outline,
            color: AppColors.textColor2,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Note',
            style: TextStyle(
              color: AppColors.textColor2,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
