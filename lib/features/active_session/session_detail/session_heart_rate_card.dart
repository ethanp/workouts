import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/session_detail/zone_distribution_section.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';

class SessionHeartRateCard extends StatelessWidget {
  const SessionHeartRateCard({
    required this.samples,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.restingHrSetting,
  });

  final List<HeartRateSample> samples;
  final int? averageHeartRate;
  final int? maxHeartRate;
  final int restingHrSetting;

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
            children: [
              const Icon(
                CupertinoIcons.heart_fill,
                size: 20,
                color: AppColors.textColor2,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Heart Rate', style: AppTypography.title),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatPill(label: 'Avg', value: _avgText()),
              const SizedBox(width: AppSpacing.sm),
              StatPill(label: 'Max', value: _maxText()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MetricsMiniChart(samples: samples),
          if (samples.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ZoneDistributionSection(
              samples: samples,
              restingHrSetting: restingHrSetting,
            ),
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
