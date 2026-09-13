import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/activity_calendar_day.dart';

class const ActivityCalendar({
  required final Map<DateTime, ActivityCalendarDay> activityData,
  required final void Function(DateTime date) onDateSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceLg,
        ELayout.spaceLg,
        ELayout.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Calendar', style: EText.section),
          const SizedBox(height: ELayout.spaceSm),
          EHeatmapLegend(scale: AerobicLoadCalendar.scale),
          const SizedBox(height: ELayout.spaceMd),
          _grid(),
        ],
      ),
    );
  }

  Widget _grid() {
    if (activityData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(ELayout.spaceXl),
        child: Center(child: Text('No activity yet', style: EText.caption)),
      );
    }

    final oldest = activityData.keys.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    final now = DateTime.now();
    return EMonthStackCalendar<DateTime>(
      firstVisibleMonth: DateTime(oldest.year, oldest.month, 1),
      lastVisibleMonth: DateTime(now.year, now.month, 1),
      presentationFor: (date) =>
          AerobicLoadCalendar.day(date, activityData[date.startOfDay]),
      weekPresentation: (weekMonday) =>
          AerobicLoadCalendar.week(weekMonday, activityData),
      monthPresentation: (monthStart) =>
          AerobicLoadCalendar.month(monthStart, activityData),
      onDaySelected: (day) => onDateSelected(day.date),
    );
  }
}

abstract final class AerobicLoadCalendar() {
  static final scale = EFixedThresholdHeatmapScale(
    legendTitle: 'Aerobic load · cardio Z2–5 minutes',
    bands: const [
      EHeatmapBand(upperBound: 0, caption: '0'),
      EHeatmapBand(upperBound: 15, caption: '1–15m'),
      EHeatmapBand(upperBound: 30, caption: '16–30m'),
      EHeatmapBand(upperBound: 45, caption: '31–45m'),
      EHeatmapBand(upperBound: double.infinity, caption: '46m+'),
    ],
  );

  static ECalendarDayPresentation<DateTime> day(
    DateTime date,
    ActivityCalendarDay? entry,
  ) {
    final day = date.startOfDay;
    if (entry == null || !entry.hasActivity) {
      return ECalendarDayPresentation(
        date: day,
        id: day,
        semanticsLabel: 'No activity',
        visual: const ECalendarDayEmpty(),
      );
    }

    final markers = [
      if (entry.hasCardio) const ECalendarDayMarker(label: 'Cardio'),
      if (entry.hasStrength) const ECalendarDayMarker(label: 'Strength'),
    ];

    if (!entry.cardioHasHrData) {
      return ECalendarDayPresentation(
        date: day,
        id: day,
        semanticsLabel: _recordedWithoutMeasureLabel(entry),
        visual: const ECalendarDayRecordedWithoutMeasure(),
        markers: markers,
      );
    }

    final z25Minutes = entry.cardioZoneTime.gteZone2Minutes;
    return ECalendarDayPresentation(
      date: day,
      id: day,
      semanticsLabel: '$z25Minutes cardio Z2–5 minutes',
      visual: ECalendarDayMeasuredHeat(
        intensity: scale.intensityFor(z25Minutes),
      ),
      secondaryLabel: '${z25Minutes}m',
      markers: markers,
    );
  }

  static ECalendarPeriodPresentation week(
    DateTime weekMonday,
    Map<DateTime, ActivityCalendarDay> activityData,
  ) {
    var activeDays = 0;
    var cardioZ25Minutes = 0;
    for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
      final entry = activityData[weekMonday.shiftedByDays(offset)];
      if (entry == null || !entry.hasActivity) continue;
      activeDays++;
      if (entry.cardioHasHrData) {
        cardioZ25Minutes += entry.cardioZoneTime.gteZone2Minutes;
      }
    }
    return ECalendarPeriodPresentation(
      activeDays: activeDays,
      measureCaption: cardioZ25Minutes > 0 ? '${cardioZ25Minutes}m' : null,
    );
  }

  static ECalendarPeriodPresentation month(
    DateTime monthStart,
    Map<DateTime, ActivityCalendarDay> activityData,
  ) {
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    var activeDays = 0;
    var cardioZ25Minutes = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final entry = activityData[DateTime(monthStart.year, monthStart.month, day)];
      if (entry == null || !entry.hasActivity) continue;
      activeDays++;
      if (entry.cardioHasHrData) {
        cardioZ25Minutes += entry.cardioZoneTime.gteZone2Minutes;
      }
    }
    return ECalendarPeriodPresentation(
      activeDays: activeDays,
      measureCaption: cardioZ25Minutes > 0 ? '${cardioZ25Minutes}m' : null,
    );
  }

  static String _recordedWithoutMeasureLabel(ActivityCalendarDay entry) {
    if (entry.hasCardio && entry.hasStrength) {
      return 'Cardio and strength recorded without heart-rate measure';
    }
    if (entry.hasCardio) return 'Cardio recorded without heart-rate measure';
    return 'Strength recorded';
  }
}
