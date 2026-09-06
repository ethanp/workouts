import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

/// Shows the 5-zone heart-rate breakdown for a single cardio workout.
class const WorkoutPolarizationCard({
  required final List<CardioHeartRateSample> samples,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();

    final zoneTime = _compute();
    if (zoneTime.total == 0) return const SizedBox.shrink();
    final representedZoneIndexes = _representedZoneIndexes(zoneTime);

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
          _header(zoneTime),
          const SizedBox(height: ELayout.spaceMd),
          _proportionalBar(zoneTime),
          const SizedBox(height: ELayout.spaceMd),
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
          Icons.graphic_eq,
          size: 18,
          color: EColors.textSecondary,
        ),
        const SizedBox(width: ELayout.spaceSm),
        Expanded(child: Text('Zone Distribution', style: EText.title)),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceSm,
            vertical: ELayout.spaceXs,
          ),
          decoration: BoxDecoration(
            color: HrZonePalette.zoneColors[dominantZoneIndex].withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(ELayout.radiusSm),
          ),
          child: Text(
            HrZonePalette.zoneNames[dominantZoneIndex],
            style: EText.caption.copyWith(
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
            style: EText.section.copyWith(
              color: HrZonePalette.zoneColors[zoneIndex],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatZoneDuration(seconds),
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: 1),
          Text(
            HrZonePalette.zoneNames[zoneIndex],
            style: EText.caption.copyWith(
              color: EColors.textMuted,
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

    return HrZoneClassifier.compute(timestamped);
  }
}
