import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/activity_calendar/calendar_day_cell.dart';
import 'package:workouts/utils/run_formatting.dart';

class CalendarWeekRow extends StatelessWidget {
  static const summaryWidth = 60.0;

  const CalendarWeekRow({
    super.key,
    required this.monthDate,
    required this.daysInMonth,
    required this.week,
    required this.firstWeekday,
    required this.globalMax,
    required this.activityData,
    required this.unitSystem,
    required this.onDateTap,
  });

  final DateTime monthDate;
  final int daysInMonth;
  final int week;
  final int firstWeekday;
  final WeekMax globalMax;
  final Map<DateTime, ActivityCalendarDay> activityData;
  final UnitSystem unitSystem;
  final void Function(DateTime date) onDateTap;

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
            unitSystem: unitSystem,
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
        cells.add(CalendarDayCell(
          date: date,
          entry: activityData[date],
          globalMax: globalMax,
          unitSystem: unitSystem,
          onTap: () => onDateTap(date),
        ));
      } else {
        cells.add(const EmptyDayCell());
      }
    }

    return (cells, ownsWeek);
  }

}

class _WeekSummary extends StatelessWidget {
  static const _summaryFontSize = 10.0;
  static const _daysBadgeWidth = 18.0;

  const _WeekSummary({
    required this.ownsWeek,
    required this.week,
    required this.firstWeekday,
    required this.monthDate,
    required this.activityData,
    required this.globalMax,
    required this.unitSystem,
  });

  final bool ownsWeek;
  final int week;
  final int firstWeekday;
  final DateTime monthDate;
  final Map<DateTime, ActivityCalendarDay> activityData;
  final WeekMax globalMax;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final stats = ownsWeek ? _aggregate() : null;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: CalendarWeekRow.summaryWidth,
        child: stats != null && stats.activeDays > 0
            ? _content(stats)
            : null,
      ),
    );
  }

  _WeekStats _aggregate() {
    final sundayOffset =
        week * DateTime.daysPerWeek + 6 - (firstWeekday - 1);
    final sunday =
        DateTime(monthDate.year, monthDate.month, sundayOffset + 1);
    final monday = sunday.subtract(const Duration(days: 6));

    var activeDays = 0;
    var cardioMeters = 0.0;
    var sessionMinutes = 0;
    var gteZone2Minutes = 0;
    var hasHrData = false;

    for (var i = 0; i < DateTime.daysPerWeek; i++) {
      final date = monday.add(Duration(days: i));
      final entry = activityData[date];
      if (entry != null && entry.hasActivity) {
        activeDays++;
        cardioMeters += entry.totalCardioDistanceMeters;
        sessionMinutes += entry.totalSessionDurationSeconds ~/ 60;
        gteZone2Minutes += entry.cardioZoneTime.gteZone2Minutes;
        if (entry.cardioHasHrData) hasHrData = true;
      }
    }

    return _WeekStats(
      activeDays: activeDays,
      cardioMeters: cardioMeters,
      sessionMinutes: sessionMinutes,
      gteZone2Minutes: gteZone2Minutes,
      hasHrData: hasHrData,
    );
  }

  Widget _content(_WeekStats stats) {
    final intensity = CalendarDayCell.intensityForDay(
      cardioMeters: stats.cardioMeters,
      sessionMinutes: stats.sessionMinutes,
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
      parts.add(Format.distanceCompact(stats.cardioMeters, unitSystem));
    }
    if (stats.sessionMinutes > 0) parts.add('${stats.sessionMinutes}m');

    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: _summaryFontSize,
        fontWeight: intensity > 0.5 ? FontWeight.w600 : FontWeight.normal,
        color: CupertinoColors.white.withValues(
          alpha: 0.4 + intensity * 0.6,
        ),
      ),
    );
  }

  Widget _zoneLabel(int gteZone2Minutes) {
    return Text(
      '${gteZone2Minutes}z',
      style: TextStyle(
        fontSize: _summaryFontSize - 1,
        color: AppColors.textColor4,
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
            color: CupertinoColors.white,
            fontSize: _summaryFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WeekStats {
  const _WeekStats({
    required this.activeDays,
    required this.cardioMeters,
    required this.sessionMinutes,
    required this.gteZone2Minutes,
    required this.hasHrData,
  });

  final int activeDays;
  final double cardioMeters;
  final int sessionMinutes;
  final int gteZone2Minutes;
  final bool hasHrData;
}
