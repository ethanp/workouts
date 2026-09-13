import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/cardio_session_verdict.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

import 'cardio_detail_card.dart';

class const SessionVerdictCard({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final verdict = CardioSessionVerdict.fromWorkout(workout);
    return CardioDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(verdict.aerobicJob.label, style: EText.title),
          const SizedBox(height: ELayout.spaceXs),
          Text(_evidenceLine(verdict), style: EText.section),
          const SizedBox(height: ELayout.spaceSm),
          Wrap(
            spacing: ELayout.spaceSm,
            runSpacing: ELayout.spaceXs,
            children: [
              if (workout.zoneTime.total > 0) _zoneChip(verdict),
              if (workout.averageHeartRateBpm != null)
                Text(
                  '${workout.averageHeartRateBpm!.round()} bpm',
                  style: EText.body.medium.copyWith(
                    color: EColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ELayout.spaceSm),
          Text(
            workout.shortProvenanceCaption,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          Text(
            workout.startedAt.dateAtTime,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _evidenceLine(CardioSessionVerdict verdict) {
    final parts = <String>[workout.duration.formattedHms];
    if (verdict.primaryWork.headline.isNotEmpty) {
      parts.add(verdict.primaryWork.headline);
    }
    final supporting = verdict.primaryWork.supporting;
    if (supporting != null && supporting.isNotEmpty) {
      parts.add(supporting);
    }
    return parts.join('  ·  ');
  }

  Widget _zoneChip(CardioSessionVerdict verdict) {
    final zoneColor = HrZonePalette.zoneColors[verdict.dominantZoneIndex];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: zoneColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        HrZonePalette.zoneNames[verdict.dominantZoneIndex],
        style: EText.caption.copyWith(
          color: zoneColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
