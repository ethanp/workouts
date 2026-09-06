import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/active_session/session_indicators.dart';

class const SessionResumeActionRow({
  required final bool isPaused,
  required final bool watchConnected,
  required final VoidCallback onTogglePause,
  required final VoidCallback onAddNote,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _pauseButton(),
      if (isPaused) ...[const SizedBox(width: ELayout.spaceMd), _pausedPill()],
      const SizedBox(width: ELayout.spaceMd),
      _addNoteButton(),
      if (!isPaused) ...[
        const Spacer(),
        WatchConnectionIndicator(isConnected: watchConnected),
      ],
    ],
  );

  Widget _pauseButton() => FilledButton.icon(
    onPressed: onTogglePause,
    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16),
    label: Text(isPaused ? 'Resume' : 'Pause'),
  );

  Widget _pausedPill() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceMd,
      vertical: ELayout.spaceSm,
    ),
    decoration: BoxDecoration(
      color: EColors.warning.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(ELayout.radiusSm),
      border: Border.all(color: EColors.warning),
    ),
    child: Text(
      'Paused',
      style: EText.caption.copyWith(
        color: EColors.warning,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _addNoteButton() => FilledButton.tonalIcon(
    onPressed: onAddNote,
    icon: const Icon(Icons.edit_outlined, size: 16),
    label: const Text('Note'),
  );
}
