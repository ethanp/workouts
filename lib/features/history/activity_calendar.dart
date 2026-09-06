import 'dart:math' as math;
import 'package:ethan_ui/ethan_ui.dart';

import 'package:flutter/material.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/features/history/calendar_day_cell.dart';
import 'package:workouts/features/history/calendar_week_row.dart';

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
          _legend(),
          const SizedBox(height: ELayout.spaceMd),
          _grid(),
        ],
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        Text('Less', style: EText.caption),
        const SizedBox(width: ELayout.spaceSm),
        ...EHeatmapIntensity.legendSwatches,
        const SizedBox(width: ELayout.spaceSm),
        Text('More', style: EText.caption),
        const Spacer(),
        Text('mi · min', style: EText.caption),
      ],
    );
  }

  Widget _grid() {
    if (activityData.isEmpty) return _emptyState();

    final globalMax = _computeGlobalMax();
    final months = _buildMonths(globalMax);
    if (months.isEmpty) return _emptyState();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: months,
      ),
    );
  }

  WeekMax _computeGlobalMax() {
    double maxCardioMeters = 0;
    int maxSessionMinutes = 0;
    for (final entry in activityData.entries) {
      if (!entry.value.hasActivity) continue;
      maxCardioMeters = math.max(
        maxCardioMeters,
        entry.value.outdoorRunDistanceMeters,
      );
      final totalMinutes =
          (entry.value.totalCardioDurationSeconds +
              entry.value.totalSessionDurationSeconds) ~/
          60;
      maxSessionMinutes = math.max(maxSessionMinutes, totalMinutes);
    }
    return WeekMax(
      maxCardioMeters: maxCardioMeters,
      maxSessionMinutes: maxSessionMinutes,
    );
  }

  List<Widget> _buildMonths(WeekMax globalMax) {
    if (activityData.isEmpty) return [];

    final oldest = activityData.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final now = DateTime.now();
    final months = <Widget>[];

    var cursor = DateTime(oldest.year, oldest.month, 1);
    final endMonth = DateTime(now.year, now.month, 1);

    while (!cursor.isAfter(endMonth)) {
      final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
      if (_monthHasActivity(cursor, daysInMonth)) {
        months.add(_monthWidget(cursor, daysInMonth, globalMax));
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  bool _monthHasActivity(DateTime monthDate, int daysInMonth) {
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final entry = activityData[date];
      if (entry != null && entry.hasActivity) return true;
    }
    return false;
  }

  Widget _monthWidget(DateTime monthDate, int daysInMonth, WeekMax globalMax) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _monthHeader(monthDate),
        _dayOfWeekRow(),
        ..._weekRows(monthDate, daysInMonth, globalMax),
        const SizedBox(height: ELayout.spaceMd),
      ],
    );
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Widget _monthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 4),
      child: Text(
        '${_monthNames[date.month - 1]} ${date.year}',
        style: EText.caption.copyWith(
          color: EColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _dayOfWeekRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final label in _dayLabels)
          SizedBox(
            width: CalendarDayCell.cellExtent,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: EText.caption.copyWith(
                color: EColors.textMuted,
                fontSize: 9,
              ),
            ),
          ),
        const SizedBox(width: CalendarWeekRow.summaryWidth + 8),
      ],
    );
  }

  List<Widget> _weekRows(
    DateTime monthDate,
    int daysInMonth,
    WeekMax globalMax,
  ) {
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday;
    final totalDays = firstWeekday - 1 + daysInMonth;
    final weeksInMonth = (totalDays / DateTime.daysPerWeek).ceil();

    return List.generate(weeksInMonth, (week) {
      return CalendarWeekRow(
        monthDate: monthDate,
        daysInMonth: daysInMonth,
        week: week,
        firstWeekday: firstWeekday,
        globalMax: globalMax,
        activityData: activityData,
        onDateSelected: onDateSelected,
      );
    });
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(ELayout.spaceXl),
      child: Center(
        child: Text('No activity yet', style: EText.caption),
      ),
    );
  }
}
