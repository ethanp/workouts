import 'package:flutter/cupertino.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/polarization_week.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/training_load_calculator.dart';

class ZoneDistributionSection extends StatefulWidget {
  const ZoneDistributionSection({
    required this.samples,
    required this.restingHrSetting,
  });

  final List<HeartRateSample> samples;
  final int restingHrSetting;

  @override
  State<ZoneDistributionSection> createState() =>
      ZoneDistributionSectionState();
}

class ZoneDistributionSectionState extends State<ZoneDistributionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                'Zone Distribution',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                _expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 11,
                color: AppColors.textColor4,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          ZoneBreakdown(
            samples: widget.samples,
            restingHrSetting: widget.restingHrSetting,
          ),
        ],
      ],
    );
  }
}

class ZoneBreakdown extends StatelessWidget {
  const ZoneBreakdown({required this.samples, required this.restingHrSetting});

  final List<HeartRateSample> samples;
  final int restingHrSetting;

  static const _aerobicColor = Color(0xFF3FB37F);
  static const _grayZoneColor = Color(0xFFF0B347);
  static const _vo2maxColor = Color(0xFFE15A64);

  @override
  Widget build(BuildContext context) {
    final polarization = _compute();
    if (!polarization.hasData) {
      return Text(
        'Not enough HR data to compute zones.',
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shown as Aerobic Base · Gray Zone · VO₂max — metabolic context only.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (polarization.aerobicBaseSeconds > 0)
                  Flexible(
                    flex: polarization.aerobicBaseSeconds,
                    child: Container(color: _aerobicColor),
                  ),
                if (polarization.grayZoneSeconds > 0)
                  Flexible(
                    flex: polarization.grayZoneSeconds,
                    child: Container(color: _grayZoneColor),
                  ),
                if (polarization.vo2maxSeconds > 0)
                  Flexible(
                    flex: polarization.vo2maxSeconds,
                    child: Container(color: _vo2maxColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _pill('${polarization.aerobicBaseMinutes}m Base', _aerobicColor),
            const SizedBox(width: AppSpacing.xs),
            _pill('${polarization.grayZoneMinutes}m Gray', _grayZoneColor),
            const SizedBox(width: AppSpacing.xs),
            _pill('${polarization.vo2maxMinutes}m VO₂max', _vo2maxColor),
          ],
        ),
      ],
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color, fontSize: 11),
      ),
    );
  }

  PolarizationWeek _compute() {
    final calculator = TrainingLoadCalculator(
      restingHeartRate: restingHrSetting,
    );

    final timestamped =
        samples
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

class StatPill extends StatelessWidget {
  const StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Row(
        children: [
          Text(
            '$label ',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          Text(value, style: AppTypography.caption),
        ],
      ),
    );
  }
}
