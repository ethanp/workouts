import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/activity_calendar/calendar_constants.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/activity_calendar/calendar_helpers.dart';

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.entry,
    required this.globalMax,
    required this.unitSystem,
    required this.onTap,
  });

  final DateTime date;
  final ActivityCalendarDay? entry;
  final WeekMax globalMax;
  final UnitSystem unitSystem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActivity = entry?.hasActivity ?? false;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final intensity = hasActivity
        ? intensityForDay(
            runMeters: entry!.totalRunDistanceMeters,
            sessionMinutes: entry!.totalSessionDurationSeconds ~/ 60,
            globalMax: globalMax,
          )
        : 0.0;
    final cellColor = hasActivity
        ? intensityColor(intensity)
        : AppColors.backgroundDepth3.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: calendarCellSize,
        height: calendarCellSize,
        margin: const EdgeInsets.all(calendarCellMargin),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isToday
                ? AppColors.accentPrimary
                : hasActivity
                ? intensityColor(intensity).withValues(alpha: 0.6)
                : AppColors.borderDepth1.withValues(alpha: 0.4),
            width: isToday ? 1.5 : 0.5,
          ),
          boxShadow: hasActivity
              ? [
                  BoxShadow(
                    color: cellColor.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: hasActivity ? _activeContent(intensity) : _inactiveContent(),
      ),
    );
  }

  Widget _inactiveContent() {
    return Center(
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textColor4.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _activeContent(double intensity) {
    const textColor = Color.fromARGB(255, 234, 221, 209);

    return Stack(
      children: [
        Positioned(left: 3, top: 2, child: _dayNumber(textColor)),
        Positioned(right: 2, top: 12, child: _activityLabel(textColor)),
        Positioned(right: 2, bottom: 2, child: _zone2Label(textColor)),
      ],
    );
  }

  Widget _dayNumber(Color textColor) {
    return Text(
      '${date.day}',
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w500,
        color: textColor.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _activityLabel(Color textColor) {
    final parts = <String>[];
    if (entry!.totalRunDistanceMeters > 0) {
      parts.add(Format.distanceCompact(entry!.totalRunDistanceMeters, unitSystem));
    }
    if (entry!.totalSessionDurationSeconds > 0) {
      parts.add('${entry!.totalSessionDurationSeconds ~/ 60}m');
    }
    return Text(
      parts.isEmpty ? '-' : parts.join(' · '),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w300,
        color: textColor,
      ),
    );
  }

  Widget _zone2Label(Color textColor) {
    if (!entry!.runHasHrData || entry!.runZone2Minutes <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      '${entry!.runZone2Minutes}z',
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 8, color: textColor.withValues(alpha: 0.75)),
    );
  }
}

class EmptyDayCell extends StatelessWidget {
  const EmptyDayCell({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: calendarCellSize, height: calendarCellSize);
  }
}
