import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/utils/run_formatting.dart';

class const SessionSummaryCard({
  required final Session session,
  final VoidCallback? onEditDuration,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Summary', style: EText.title),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: ELayout.spaceMd),
          _durationRow(),
          const SizedBox(height: ELayout.spaceSm),
          _summaryRow(
            icon: Icons.calendar_today,
            label: 'Completed',
            value: Format.dateTime(session.completedAt ?? session.startedAt),
          ),
          if (session.feeling?.isNotEmpty ?? false) ...[
            const SizedBox(height: ELayout.spaceSm),
            _summaryRow(
              icon: Icons.favorite,
              label: 'Feeling',
              value: session.feeling!,
            ),
          ],
          if (session.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: ELayout.spaceMd),
            Text('Notes', style: EText.section),
            const SizedBox(height: ELayout.spaceXs),
            Text(
              session.notes!,
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _durationRow() {
    return Row(
      children: [
        Icon(Icons.access_time, size: 20, color: EColors.textTertiary),
        const SizedBox(width: ELayout.spaceSm),
        Text(
          'Duration: ',
          style: EText.body.medium.copyWith(color: EColors.textTertiary),
        ),
        Text(_durationText(session.duration), style: EText.body.medium),
        if (onEditDuration != null) ...[
          const SizedBox(width: ELayout.spaceMd),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: EColors.accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: ELayout.spaceSm,
                vertical: ELayout.spaceXs,
              ),
            ),
            onPressed: onEditDuration,
            icon: const Icon(Icons.edit, size: 14),
            label: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: EColors.textTertiary),
        const SizedBox(width: ELayout.spaceSm),
        Text(
          '$label: ',
          style: EText.body.medium.copyWith(color: EColors.textTertiary),
        ),
        Text(value, style: EText.body.medium),
      ],
    );
  }

  Widget _statusBadge() {
    final isComplete = session.isComplete;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: isComplete ? EColors.success : EColors.accent,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        isComplete ? 'Completed' : 'In Progress',
        style: const TextStyle(
          color: Colors.white,
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
