import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/polarization_week.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

class const ZoneDistributionSection({
  required final List<HeartRateSample> samples,
}) extends StatefulWidget {
  @override
  State<ZoneDistributionSection> createState() =>
      ZoneDistributionSectionState();
}

class ZoneDistributionSectionState() extends State<ZoneDistributionSection> {
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
                style: EText.caption.copyWith(
                  color: EColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: ELayout.spaceXs),
              Icon(
                _expanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 11,
                color: EColors.textMuted,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: ELayout.spaceSm),
          ZoneBreakdown(samples: widget.samples),
        ],
      ],
    );
  }
}

class const ZoneBreakdown({required final List<HeartRateSample> samples})
    extends StatelessWidget {
  static const _aerobicColor = Color(0xFF3FB37F);
  static const _grayZoneColor = Color(0xFFF0B347);
  static const _vo2maxColor = Color(0xFFE15A64);

  @override
  Widget build(BuildContext context) {
    final polarization = _compute();
    if (!polarization.hasData) {
      return Text(
        'Not enough HR data to compute zones.',
        style: EText.caption.copyWith(color: EColors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shown as Aerobic Base · Gray Zone · VO₂max — metabolic context only.',
          style: EText.caption.copyWith(
            color: EColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
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
        const SizedBox(height: ELayout.spaceXs),
        Row(
          children: [
            _pill('${polarization.aerobicBaseMinutes}m Base', _aerobicColor),
            const SizedBox(width: ELayout.spaceXs),
            _pill('${polarization.grayZoneMinutes}m Gray', _grayZoneColor),
            const SizedBox(width: ELayout.spaceXs),
            _pill('${polarization.vo2maxMinutes}m VO₂max', _vo2maxColor),
          ],
        ),
      ],
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        label,
        style: EText.caption.copyWith(color: color, fontSize: 11),
      ),
    );
  }

  PolarizationWeek _compute() {
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

    return PolarizationWeek.fromHrZoneTime(
      HrZoneClassifier.compute(timestamped),
    );
  }
}

class const StatPill({required final String label, required final String value})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        border: Border.all(color: EColors.border),
      ),
      child: Row(
        children: [
          Text(
            '$label ',
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          Text(value, style: EText.caption),
        ],
      ),
    );
  }
}
