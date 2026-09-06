import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/history/charts/polarization_formatting.dart';
import 'package:workouts/features/history/charts/week_zone_data.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

class const PolarizationScrubDetailPanel({required final WeekZoneData? week})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (week == null) return _emptyState();
    if (week!.zoneTime.total == 0) return _noDataState(week!);
    return _dataState(week!);
  }

  Widget _emptyState() {
    return Text(
      'Drag to inspect a week',
      style: EText.caption.copyWith(color: EColors.textMuted),
    );
  }

  Widget _noDataState(WeekZoneData week) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Week of ${week.label}',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'No HR data — manual activity or HR not recorded.',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ],
    );
  }

  Widget _dataState(WeekZoneData week) {
    final zoneTime = week.zoneTime;
    final totalSeconds = zoneTime.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _weekHeader(week, totalSeconds ~/ 60),
        const SizedBox(height: ELayout.spaceXs),
        for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++) ...[
          if (zoneIndex > 0) const SizedBox(height: 2),
          _zoneRow(
            HrZonePalette.zoneNames[zoneIndex],
            HrZonePalette.zoneColors[zoneIndex],
            formatPolarizationZoneRange(zoneIndex + 1),
            zoneTime[zoneIndex],
            totalSeconds,
          ),
        ],
      ],
    );
  }

  Widget _weekHeader(WeekZoneData week, int totalMinutes) {
    return Row(
      children: [
        Text(
          'Week of ${week.label}',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ELayout.spaceSm),
        Text(
          '· Total zone time: ${formatPolarizationMinutes(totalMinutes)}',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ],
    );
  }

  Widget _zoneRow(
    String label,
    Color color,
    String range,
    int seconds,
    int totalSeconds,
  ) {
    final fraction = totalSeconds > 0 ? seconds / totalSeconds : 0.0;
    final percent = (fraction * 100).round().clamp(0, 100);
    return Row(
      children: [
        _zoneLabel(label, range),
        Expanded(child: _fractionBar(color, fraction)),
        const SizedBox(width: ELayout.spaceSm),
        _percentLabel(percent),
        const SizedBox(width: ELayout.spaceSm),
        _minutesLabel(seconds ~/ 60),
      ],
    );
  }

  Widget _zoneLabel(String label, String range) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          Text(
            range,
            style: const TextStyle(fontSize: 8, color: EColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _fractionBar(Color color, double fraction) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: EColors.surfaceRaised,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _percentLabel(int percent) {
    return SizedBox(
      width: 34,
      child: Text(
        '$percent%',
        textAlign: TextAlign.right,
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    );
  }

  Widget _minutesLabel(int minutes) {
    return SizedBox(
      width: 40,
      child: Text(
        formatPolarizationMinutes(minutes),
        textAlign: TextAlign.right,
        style: EText.caption.copyWith(color: EColors.textMuted),
      ),
    );
  }
}
