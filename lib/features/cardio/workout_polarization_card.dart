import 'package:flutter/cupertino.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/training_load_calculator.dart';

/// Shows the 5-zone heart-rate breakdown for a single cardio workout.
class WorkoutPolarizationCard extends StatelessWidget {
  const WorkoutPolarizationCard({
    super.key,
    required this.samples,
    required this.restingHeartRate,
  });

  final List<CardioHeartRateSample> samples;
  final int restingHeartRate;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();

    final zoneTime = _compute();
    if (zoneTime.total == 0) return const SizedBox.shrink();
    final representedZoneIndexes = _representedZoneIndexes(zoneTime);

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
          _header(zoneTime),
          const SizedBox(height: AppSpacing.md),
          _proportionalBar(zoneTime),
          const SizedBox(height: AppSpacing.md),
          _zoneLabels(zoneTime, representedZoneIndexes),
        ],
      ),
    );
  }

  Widget _header(HrZoneTime zoneTime) {
    final dominantZoneIndex = _dominantZoneIndex(zoneTime);
    return Row(
      children: [
        const Icon(
          CupertinoIcons.waveform_path,
          size: 18,
          color: AppColors.textColor2,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('Zone Distribution', style: AppTypography.title)),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: HrZonePalette.zoneColors[dominantZoneIndex].withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            HrZonePalette.zoneNames[dominantZoneIndex],
            style: AppTypography.caption.copyWith(
              color: HrZonePalette.zoneColors[dominantZoneIndex],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _proportionalBar(HrZoneTime zoneTime) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++)
              _barSegment(
                seconds: zoneTime[zoneIndex],
                totalSeconds: zoneTime.total,
                color: HrZonePalette.zoneColors[zoneIndex],
              ),
          ],
        ),
      ),
    );
  }

  Widget _barSegment({
    required int seconds,
    required int totalSeconds,
    required Color color,
  }) {
    if (seconds <= 0 || totalSeconds <= 0) return const SizedBox.shrink();
    return Flexible(
      flex: seconds,
      child: Container(color: color),
    );
  }

  Widget _zoneLabels(HrZoneTime zoneTime, List<int> representedZoneIndexes) {
    return Row(
      children: [
        for (final zoneIndex in representedZoneIndexes)
          _zoneCell(zoneTime, zoneIndex),
      ],
    );
  }

  List<int> _representedZoneIndexes(HrZoneTime zoneTime) {
    final representedZoneIndexes = <int>[];
    for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++) {
      if (zoneTime[zoneIndex] > 0) representedZoneIndexes.add(zoneIndex);
    }
    return representedZoneIndexes;
  }

  int _dominantZoneIndex(HrZoneTime zoneTime) {
    var dominantZoneIndex = 0;
    var dominantZoneSeconds = zoneTime[0];
    for (var zoneIndex = 1; zoneIndex < 5; zoneIndex++) {
      if (zoneTime[zoneIndex] <= dominantZoneSeconds) continue;
      dominantZoneIndex = zoneIndex;
      dominantZoneSeconds = zoneTime[zoneIndex];
    }
    return dominantZoneIndex;
  }

  Widget _zoneCell(HrZoneTime zoneTime, int zoneIndex) {
    final seconds = zoneTime[zoneIndex];
    final percent = (seconds / zoneTime.total * 100).round();
    return Expanded(
      child: Column(
        children: [
          Text(
            '$percent%',
            style: AppTypography.subtitle.copyWith(
              color: HrZonePalette.zoneColors[zoneIndex],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatZoneDuration(seconds),
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: 1),
          Text(
            HrZonePalette.zoneNames[zoneIndex],
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor4,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatZoneDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m';
  }

  HrZoneTime _compute() {
    final calculator = TrainingLoadCalculator(
      restingHeartRate: restingHeartRate,
    );

    final timestamped = <TimestampedHeartRate>[];
    for (final sample in samples) {
      timestamped.add(
        TimestampedHeartRate(timestamp: sample.timestamp, bpm: sample.bpm),
      );
    }
    timestamped.sort(
      (firstSample, secondSample) =>
          firstSample.timestamp.compareTo(secondSample.timestamp),
    );

    final result = calculator.compute(timestamped);
    return result.zoneTime;
  }
}
