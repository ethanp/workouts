import 'package:flutter/cupertino.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

class SessionNotesCard extends StatelessWidget {
  const SessionNotesCard({required this.notes});

  final List<SessionNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.doc_text,
                size: 20,
                color: AppColors.textColor2,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Session Notes', style: AppTypography.title),
              const Spacer(),
              Text(
                '${notes.length}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...notes.map((note) => _buildNoteItem(note)),
        ],
      ),
    );
  }

  Widget _buildNoteItem(SessionNote note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: _getTypeColor(note.noteType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              note.noteType.icon,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.content, style: AppTypography.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Format.time(note.timestamp),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textColor4,
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
      SessionNoteType.observation => AppColors.textColor2,
      SessionNoteType.modification => AppColors.accentPrimary,
      SessionNoteType.painSignal => AppColors.warning,
      SessionNoteType.breakthrough => AppColors.success,
    };
  }
}
