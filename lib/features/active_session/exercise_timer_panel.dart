import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

enum TimerPhase() {
  idle,
  setup,
  work,
  rest,
  complete,
}

class const ExerciseTimerPanel({
  required final TimerPhase phase,
  required final Duration? remaining,

  /// The current phase's configured full length. Shown alongside the live
  /// countdown so the target duration stays visible while it ticks down.
  final Duration? phaseLength,
  required final bool isPaused,
  required final VoidCallback onStart,
  required final VoidCallback onPause,
  required final VoidCallback onResume,
  required final VoidCallback onReset,
  required final void Function(int seconds) onAdjustTime,
  required final bool canPause,
  required final bool canResume,
  required final bool canStart,
  required final bool canReset,
  required final bool canAdjust,
  required final bool hasSetupPhase,
  required final bool hasWorkPhase,
  required final bool hasRestPhase,
}) extends StatelessWidget {
  String get _phaseLabel => switch (phase) {
    TimerPhase.setup => 'Setup',
    TimerPhase.work => 'Work',
    TimerPhase.rest => 'Rest',
    TimerPhase.complete => 'Complete',
    TimerPhase.idle =>
      hasSetupPhase || hasWorkPhase || hasRestPhase ? 'Ready' : 'Timer',
  };

  String get _timeDisplay =>
      remaining == null ? '--:--' : remaining!.formattedClock;

  /// True while a timed phase is running/paused and has a configured length,
  /// so the countdown can display its target duration.
  bool get _showsPhaseLength =>
      remaining != null && phaseLength != null && phaseLength! > Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(),
          const SizedBox(height: ELayout.spaceXs),
          _countdownRow(),
          const SizedBox(height: ELayout.spaceSm),
          _controlsRow(),
        ],
      ),
    );
  }

  Widget _countdownRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _timeDisplay,
          style: EText.title.copyWith(
            letterSpacing: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (_showsPhaseLength) ...[
          const SizedBox(width: ELayout.spaceXs),
          Text(
            '/ ${phaseLength!.formattedClock}',
            style: EText.caption.copyWith(
              color: EColors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  Widget _headerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _phaseLabel,
          style: EText.section.copyWith(color: EColors.textTertiary),
        ),
        Text(
          isPaused ? 'Paused' : '',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ],
    );
  }

  Widget _controlsRow() {
    return Row(
      children: [
        if (canAdjust) ...[
          _timerButton('-10s', () => onAdjustTime(-10)),
          const SizedBox(width: ELayout.spaceXs),
          _timerButton('+10s', () => onAdjustTime(10)),
          const SizedBox(width: ELayout.spaceSm),
        ],
        Expanded(child: _primaryButton()),
        const SizedBox(width: ELayout.spaceXs),
        Expanded(child: _resetButton()),
      ],
    );
  }

  Widget _primaryButton() => FilledButton(
    onPressed: canPause
        ? onPause
        : canResume
        ? onResume
        : canStart
        ? onStart
        : null,
    child: Text(
      canPause
          ? 'Pause'
          : canResume
          ? 'Resume'
          : 'Start',
    ),
  );

  Widget _resetButton() => FilledButton.tonal(
    onPressed: canReset ? onReset : null,
    child: const Text('Reset'),
  );

  Widget _timerButton(String label, VoidCallback onPressed) {
    return FilledButton.tonal(onPressed: onPressed, child: Text(label));
  }
}
