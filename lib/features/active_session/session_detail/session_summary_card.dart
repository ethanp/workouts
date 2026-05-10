import 'package:flutter/cupertino.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Summary', style: AppTypography.title),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _summaryRow(
            icon: CupertinoIcons.time,
            label: 'Duration',
            value: _durationText(session.duration),
          ),
          const SizedBox(height: AppSpacing.sm),
          _summaryRow(
            icon: CupertinoIcons.calendar,
            label: 'Completed',
            value: Format.dateTime(session.completedAt ?? session.startedAt),
          ),
          if (session.feeling?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            _summaryRow(
              icon: CupertinoIcons.heart_fill,
              label: 'Feeling',
              value: session.feeling!,
            ),
          ],
          if (session.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Notes', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              session.notes!,
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textColor3),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: AppTypography.body.copyWith(color: AppColors.textColor3),
        ),
        Text(value, style: AppTypography.body),
      ],
    );
  }

  Widget _statusBadge() {
    final isComplete = session.completedAt != null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.success : AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isComplete ? 'Completed' : 'In Progress',
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _durationText(Duration? duration) {
    if (duration == null) return 'N/A';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
