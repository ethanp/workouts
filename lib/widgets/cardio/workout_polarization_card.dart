import 'package:flutter/cupertino.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/polarization_week.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/training_load_calculator.dart';

const _aerobicColor = Color(0xFF3FB37F);
const _grayZoneColor = Color(0xFFF0B347);
const _vo2maxColor = Color(0xFFE15A64);

/// Shows the 3-bucket polarization breakdown for a single cardio workout.
///
/// Uses the same functional groupings as the history [PolarizationChart] so the
/// user builds a consistent mental model: aerobic base / gray zone / VO₂max
/// stimulus at both the aggregate and individual-workout level.
///
/// Renders nothing if samples is empty — absence is honest.
class WorkoutPolarizationCard extends StatelessWidget {
  const WorkoutPolarizationCard({
    super.key,
    required this.samples,
    required this.maxHeartRate,
    required this.restingHeartRate,
  });

  final List<CardioHeartRateSample> samples;
  final int maxHeartRate;
  final int restingHeartRate;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();

    final polarization = _compute();
    if (!polarization.hasData) return const SizedBox.shrink();

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
          _header(polarization),
          const SizedBox(height: AppSpacing.md),
          _proportionalBar(polarization),
          const SizedBox(height: AppSpacing.md),
          _bucketLabels(polarization),
        ],
      ),
    );
  }

  Widget _header(PolarizationWeek polarization) {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.waveform_path,
          size: 18,
          color: AppColors.textColor2,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('Zone Distribution', style: AppTypography.title),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: _qualityColor(polarization).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            polarization.qualityLabel,
            style: AppTypography.caption.copyWith(
              color: _qualityColor(polarization),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _proportionalBar(PolarizationWeek polarization) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            _barSegment(
              polarization.aerobicFraction,
              _aerobicColor,
              isFirst: true,
            ),
            _barSegment(
              polarization.grayFraction,
              _grayZoneColor,
            ),
            _barSegment(
              polarization.vo2maxFraction,
              _vo2maxColor,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _barSegment(
    double fraction,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    if (fraction <= 0) return const SizedBox.shrink();
    return Flexible(
      flex: (fraction * 1000).round(),
      child: Container(color: color),
    );
  }

  Widget _bucketLabels(PolarizationWeek polarization) {
    return Row(
      children: [
        _bucketCell(
          'Aerobic Base',
          _aerobicColor,
          polarization.aerobicFraction,
          polarization.aerobicBaseMinutes,
        ),
        _bucketCell(
          'Gray Zone',
          _grayZoneColor,
          polarization.grayFraction,
          polarization.grayZoneMinutes,
        ),
        _bucketCell(
          'VO₂max',
          _vo2maxColor,
          polarization.vo2maxFraction,
          polarization.vo2maxMinutes,
        ),
      ],
    );
  }

  Widget _bucketCell(
    String label,
    Color color,
    double fraction,
    int minutes,
  ) {
    final percent = (fraction * 100).round();
    return Expanded(
      child: Column(
        children: [
          Text(
            '$percent%',
            style: AppTypography.subtitle.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            '${minutes}m',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: 1),
          Text(
            label,
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

  Color _qualityColor(PolarizationWeek polarization) {
    final grayPercent = polarization.grayFraction * 100;
    if (grayPercent >= 35) return _grayZoneColor;
    if (polarization.aerobicFraction >= 0.70 && grayPercent <= 15) {
      return _aerobicColor;
    }
    return AppColors.textColor3;
  }

  PolarizationWeek _compute() {
    final calculator = TrainingLoadCalculator(
      maxHeartRate: maxHeartRate,
      restingHeartRate: restingHeartRate,
    );

    final timestamped = samples
        .map(
          (sample) => TimestampedHeartRate(
            timestamp: sample.timestamp,
            bpm: sample.bpm,
          ),
        )
        .toList()
      ..sort(
        (firstSample, secondSample) =>
            firstSample.timestamp.compareTo(secondSample.timestamp),
      );

    final result = calculator.compute(timestamped);
    return PolarizationWeek.fromHrZoneTime(result.zoneTime);
  }
}
