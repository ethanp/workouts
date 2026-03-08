import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/activity_calendar/calendar_constants.dart';
import 'package:workouts/widgets/activity_calendar/calendar_day_cell.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/activity_calendar/calendar_helpers.dart';

class CalendarWeekRow extends StatelessWidget {
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
    final cells = <Widget>[];
    var activeDays = 0;
    var weekRunMeters = 0.0;
    var weekSessionMinutes = 0;
    var weekZone2Minutes = 0;
    var weekHasHrData = false;
    var ownsWeek = false;

    for (var day = 0; day < daysPerWeek; day++) {
      final dayOffset = week * daysPerWeek + day - (firstWeekday - 1);
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

    if (ownsWeek) {
      final sundayOffset = week * daysPerWeek + 6 - (firstWeekday - 1);
      final sunday =
          DateTime(monthDate.year, monthDate.month, sundayOffset + 1);
      final monday = sunday.subtract(const Duration(days: 6));
      for (var i = 0; i < daysPerWeek; i++) {
        final date = monday.add(Duration(days: i));
        final entry = activityData[date];
        if (entry != null && entry.hasActivity) {
          activeDays++;
          weekRunMeters += entry.totalRunDistanceMeters;
          weekSessionMinutes += entry.totalSessionDurationSeconds ~/ 60;
          weekZone2Minutes += entry.runZone2Minutes;
          if (entry.runHasHrData) weekHasHrData = true;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...cells,
          _WeekSummary(
            ownsWeek: ownsWeek,
            activeDays: activeDays,
            runMeters: weekRunMeters,
            sessionMinutes: weekSessionMinutes,
            zone2Minutes: weekZone2Minutes,
            hasHrData: weekHasHrData,
            globalMax: globalMax,
            unitSystem: unitSystem,
          ),
        ],
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.ownsWeek,
    required this.activeDays,
    required this.runMeters,
    required this.sessionMinutes,
    required this.zone2Minutes,
    required this.hasHrData,
    required this.globalMax,
    required this.unitSystem,
  });

  final bool ownsWeek;
  final int activeDays;
  final double runMeters;
  final int sessionMinutes;
  final int zone2Minutes;
  final bool hasHrData;
  final WeekMax globalMax;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: calendarSummaryWidth,
        child: ownsWeek && activeDays > 0 ? _content() : null,
      ),
    );
  }

  Widget _content() {
    final intensity = intensityForDay(
      runMeters: runMeters,
      sessionMinutes: sessionMinutes,
      globalMax: globalMax,
    );
    final parts = <String>[];
    if (runMeters > 0) parts.add(Format.distanceCompact(runMeters, unitSystem));
    if (sessionMinutes > 0) parts.add('${sessionMinutes}m');
    final summaryLabel = parts.isEmpty ? '' : parts.join(' · ');
    final summaryColor = CupertinoColors.white.withValues(
      alpha: 0.4 + intensity * 0.6,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _daysBadge(),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summaryLabel,
                style: TextStyle(
                  fontSize: calendarSummaryFontSize,
                  fontWeight:
                      intensity > 0.5 ? FontWeight.w600 : FontWeight.normal,
                  color: summaryColor,
                ),
              ),
              if (hasHrData && zone2Minutes > 0)
                Text(
                  '${zone2Minutes}z',
                  style: TextStyle(
                    fontSize: calendarSummaryFontSize - 1,
                    color: AppColors.textColor4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _daysBadge() {
    final intensity = activeDays / daysPerWeek;
    return SizedBox(
      width: calendarDaysBadgeWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: intensityColor(intensity * 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$activeDays',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: calendarSummaryFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
