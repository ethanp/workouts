import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

enum TimerPhase { idle, setup, work, complete }

class ExerciseTimerPanel extends StatelessWidget {
  const ExerciseTimerPanel({
    super.key,
    required this.phase,
    required this.remaining,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    required this.onSkipToComplete,
    required this.onAdjustTime,
    required this.canPause,
    required this.canResume,
    required this.canStart,
    required this.canReset,
    required this.canAdjust,
    required this.canSkip,
    required this.hasSetupPhase,
    required this.hasWorkPhase,
  });

  final TimerPhase phase;
  final Duration? remaining;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReset;
  final VoidCallback onSkipToComplete;
  final void Function(int seconds) onAdjustTime;
  final bool canPause;
  final bool canResume;
  final bool canStart;
  final bool canReset;
  final bool canAdjust;
  final bool canSkip;
  final bool hasSetupPhase;
  final bool hasWorkPhase;

  String get _phaseLabel => switch (phase) {
    TimerPhase.setup => 'Setup',
    TimerPhase.work => 'Work',
    TimerPhase.complete => 'Complete',
    TimerPhase.idle => hasSetupPhase || hasWorkPhase ? 'Ready' : 'Timer',
  };

  String get _timeDisplay {
    if (remaining == null) return '--:--';
    final minutes = remaining!.inMinutes.remainder(60).abs();
    final seconds = remaining!.inSeconds.remainder(60).abs();
    final hours = remaining!.inHours;
    if (hours > 0) {
      final mins = minutes.toString().padLeft(2, '0');
      final secs = seconds.toString().padLeft(2, '0');
      return '${hours.toString().padLeft(2, '0')}:$mins:$secs';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _timeDisplay,
            style: AppTypography.title.copyWith(
              letterSpacing: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _primaryControls(),
          const SizedBox(height: AppSpacing.xs),
          _secondaryControls(),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _phaseLabel,
          style: AppTypography.subtitle.copyWith(color: AppColors.textColor3),
        ),
        Text(
          isPaused ? 'Paused' : '',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _primaryControls() {
    return Row(
      children: [
        if (canAdjust) ...[
          _timerButton('-10s', () => onAdjustTime(-10)),
          const SizedBox(width: AppSpacing.xs),
          _timerButton('+10s', () => onAdjustTime(10)),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            onPressed: canPause
                ? onPause
                : canResume
                ? onResume
                : canStart
                ? onStart
                : null,
            child: Text(
              canPause ? 'Pause' : canResume ? 'Resume' : 'Start',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _secondaryControls() {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.backgroundDepth4,
            disabledColor: AppColors.backgroundDepth4.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onPressed: canReset ? onReset : null,
            child: const Text(
              'Reset',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.success,
            disabledColor: AppColors.backgroundDepth4.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onPressed: canSkip ? onSkipToComplete : null,
            child: const Text(
              'Mark Complete',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timerButton(String label, VoidCallback onPressed) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.backgroundDepth4,
      borderRadius: BorderRadius.circular(AppRadius.md),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
