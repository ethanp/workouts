import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/active_session/session_detail/zone_distribution_section.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';

class const SessionHeartRateCard({
  required final List<HeartRateSample> samples,
  required final int? averageHeartRate,
  required final int? maxHeartRate,
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
            children: [
              const Icon(
                Icons.favorite,
                size: 20,
                color: EColors.textSecondary,
              ),
              const SizedBox(width: ELayout.spaceSm),
              Text('Heart Rate', style: EText.title),
            ],
          ),
          const SizedBox(height: ELayout.spaceMd),
          Row(
            children: [
              StatPill(label: 'Avg', value: _avgText()),
              const SizedBox(width: ELayout.spaceSm),
              StatPill(label: 'Max', value: _maxText()),
            ],
          ),
          const SizedBox(height: ELayout.spaceMd),
          HeartRateAndSpeedChart(samples: samples),
          if (samples.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceMd),
            ZoneDistributionSection(samples: samples),
          ],
        ],
      ),
    );
  }

  String _avgText() {
    if (averageHeartRate != null) {
      return '${averageHeartRate!} BPM';
    }
    if (samples.isEmpty) return '--';
    final averageBpm =
        (samples
                    .map((heartRateSample) => heartRateSample.bpm)
                    .reduce((firstBpm, secondBpm) => firstBpm + secondBpm) /
                samples.length)
            .round();
    return '$averageBpm BPM';
  }

  String _maxText() {
    if (maxHeartRate != null) {
      return '${maxHeartRate!} BPM';
    }
    if (samples.isEmpty) return '--';
    final maxBpm = samples
        .map((heartRateSample) => heartRateSample.bpm)
        .reduce(
          (firstBpm, secondBpm) => firstBpm > secondBpm ? firstBpm : secondBpm,
        );
    return '$maxBpm BPM';
  }
}
