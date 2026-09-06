import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/utils/run_formatting.dart';

class const SessionNotesCard({required final List<SessionNote> notes})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusXl),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description,
                size: 20,
                color: EColors.textSecondary,
              ),
              const SizedBox(width: ELayout.spaceSm),
              Text('Session Notes', style: EText.title),
              const Spacer(),
              Text(
                '${notes.length}',
                style: EText.caption.copyWith(
                  color: EColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: ELayout.spaceMd),
          ...notes.map((note) => _buildNoteItem(note)),
        ],
      ),
    );
  }

  Widget _buildNoteItem(SessionNote note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(ELayout.spaceXs),
            decoration: BoxDecoration(
              color: _getTypeColor(note.noteType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(ELayout.radiusSm),
            ),
            child: Text(
              note.noteType.icon,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.content, style: EText.body.medium),
                const SizedBox(height: ELayout.spaceXs),
                Text(
                  Format.time(note.timestamp),
                  style: EText.caption.copyWith(
                    color: EColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(SessionNoteType type) {
    return switch (type) {
      SessionNoteType.observation => EColors.textSecondary,
      SessionNoteType.modification => EColors.accent,
      SessionNoteType.painSignal => EColors.warning,
      SessionNoteType.breakthrough => EColors.success,
    };
  }
}
