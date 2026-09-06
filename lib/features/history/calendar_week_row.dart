import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/features/history/calendar_day_cell.dart';
import 'package:workouts/utils/run_formatting.dart';

class const CalendarWeekRow({
  required final DateTime monthDate,
  required final int daysInMonth,
  required final int week,
  required final int firstWeekday,
  required final WeekMax globalMax,
  required final Map<DateTime, ActivityCalendarDay> activityData,
  required final void Function(DateTime date) onDateSelected,
}) extends StatelessWidget {
  static const summaryWidth = 74.0;

  @override
  Widget build(BuildContext context) {
    final (cells, ownsWeek) = _dayCells();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...cells,
          _WeekSummary(
            ownsWeek: ownsWeek,
            week: week,
            firstWeekday: firstWeekday,
            monthDate: monthDate,
            activityData: activityData,
            globalMax: globalMax,
          ),
        ],
      ),
    );
  }

  (List<Widget>, bool) _dayCells() {
    final cells = <Widget>[];
    var ownsWeek = false;

    for (var day = 0; day < DateTime.daysPerWeek; day++) {
      final dayOffset = week * DateTime.daysPerWeek + day - (firstWeekday - 1);
      final isInMonth = dayOffset >= 0 && dayOffset < daysInMonth;

      if (isInMonth) {
        final date = DateTime(monthDate.year, monthDate.month, dayOffset + 1);
        if (day == 6) ownsWeek = true;
        cells.add(
          CalendarDayCell(
            date: date,
            entry: activityData[date],
            globalMax: globalMax,
            onActivated: () => onDateSelected(date),
          ),
        );
      } else {
        cells.add(const EmptyDayCell());
      }
    }

    return (cells, ownsWeek);
  }
}

class const _WeekSummary({
  required final bool ownsWeek,
  required final int week,
  required final int firstWeekday,
  required final DateTime monthDate,
  required final Map<DateTime, ActivityCalendarDay> activityData,
  required final WeekMax globalMax,
}) extends StatelessWidget {
  static const _summaryFontSize = 10.0;
  static const _daysBadgeWidth = 18.0;

  @override
  Widget build(BuildContext context) {
    final stats = ownsWeek ? _aggregate() : null;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: CalendarWeekRow.summaryWidth,
        child: stats != null && stats.activeDays > 0 ? _content(stats) : null,
      ),
    );
  }

  _WeekStats _aggregate() {
    final sundayOffset = week * DateTime.daysPerWeek + 6 - (firstWeekday - 1);
    final sunday = DateTime(monthDate.year, monthDate.month, sundayOffset + 1);
    final monday = sunday.shiftedByDays(-6);

    var activeDays = 0;
    var cardioMeters = 0.0;
    var totalMinutes = 0;
    var gteZone2Minutes = 0;
    var hasHrData = false;

    for (var dayOffset = 0; dayOffset < DateTime.daysPerWeek; dayOffset++) {
      final date = monday.shiftedByDays(dayOffset);
      final entry = activityData[date];
      if (entry != null && entry.hasActivity) {
        activeDays++;
        cardioMeters += entry.outdoorRunDistanceMeters;
        totalMinutes +=
            (entry.totalCardioDurationSeconds +
                entry.totalSessionDurationSeconds) ~/
            60;
        gteZone2Minutes += entry.cardioZoneTime.gteZone2Minutes;
        if (entry.cardioHasHrData) hasHrData = true;
      }
    }

    return _WeekStats(
      activeDays: activeDays,
      cardioMeters: cardioMeters,
      totalMinutes: totalMinutes,
      gteZone2Minutes: gteZone2Minutes,
      hasHrData: hasHrData,
    );
  }

  Widget _content(_WeekStats stats) {
    final intensity = CalendarDayCell.intensityForDay(
      cardioMeters: stats.cardioMeters,
      sessionMinutes: stats.totalMinutes,
      globalMax: globalMax,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _daysBadge(stats.activeDays),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _activityLabel(stats, intensity),
              if (stats.hasHrData && stats.gteZone2Minutes > 0)
                _zoneLabel(stats.gteZone2Minutes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityLabel(_WeekStats stats, double intensity) {
    final parts = <String>[];
    if (stats.cardioMeters > 0) {
      parts.add(Format.distanceCompact(stats.cardioMeters));
    }
    if (stats.totalMinutes > 0) parts.add('${stats.totalMinutes}m');

    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: _summaryFontSize,
        fontWeight: intensity > 0.5 ? FontWeight.w600 : FontWeight.normal,
        color: Colors.white.withValues(alpha: 0.4 + intensity * 0.6),
      ),
    );
  }

  Widget _zoneLabel(int gteZone2Minutes) {
    return Text(
      '${gteZone2Minutes}z2-5',
      style: TextStyle(
        fontSize: _summaryFontSize - 1,
        color: EColors.textMuted,
      ),
    );
  }

  Widget _daysBadge(int activeDays) {
    final intensity = activeDays / DateTime.daysPerWeek;
    return SizedBox(
      width: _daysBadgeWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: CalendarDayCell.intensityColor(intensity * 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$activeDays',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: _summaryFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class const _WeekStats({
  required final int activeDays,
  required final double cardioMeters,
  required final int totalMinutes,
  required final int gteZone2Minutes,
  required final bool hasHrData,
});
