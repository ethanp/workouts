import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/activity_calendar/calendar_day_cell.dart';
import 'package:workouts/widgets/activity_calendar/calendar_week_row.dart';

class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({
    super.key,
    required this.activityData,
    required this.unitSystem,
    required this.onDateTap,
  });

  final Map<DateTime, ActivityCalendarDay> activityData;
  final UnitSystem unitSystem;
  final void Function(DateTime date) onDateTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity Calendar', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          _legend(),
          const SizedBox(height: AppSpacing.md),
          _grid(),
        ],
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        const Text('Less', style: AppTypography.caption),
        const SizedBox(width: AppSpacing.sm),
        ..._intensitySquares(),
        const SizedBox(width: AppSpacing.sm),
        const Text('More', style: AppTypography.caption),
        const Spacer(),
        Text(
          unitSystem == UnitSystem.imperial ? 'mi · min' : 'km · min',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  List<Widget> _intensitySquares() {
    return List.generate(5, (index) {
      final intensity = (index + 1) / 5;
      return Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.accentPrimary.withValues(alpha: 0.15),
            AppColors.accentPrimary.withValues(alpha: 0.9),
            intensity,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    });
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
    double maxRunMeters = 0;
    int maxSessionMinutes = 0;
    for (final entry in activityData.entries) {
      if (!entry.value.hasActivity) continue;
      maxRunMeters = math.max(maxRunMeters, entry.value.totalRunDistanceMeters);
      final sessionMinutes = entry.value.totalSessionDurationSeconds ~/ 60;
      maxSessionMinutes = math.max(maxSessionMinutes, sessionMinutes);
    }
    return WeekMax(
      maxRunMeters: maxRunMeters,
      maxSessionMinutes: maxSessionMinutes,
    );
  }

  List<Widget> _buildMonths(WeekMax globalMax) {
    if (activityData.isEmpty) return [];

    final oldest = activityData.keys.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
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
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Widget _monthHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 4),
      child: Text(
        '${_monthNames[date.month - 1]} ${date.year}',
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor3,
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
            width: CalendarDayCell.cellSize + CalendarDayCell.cellMargin * 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
                fontSize: 9,
              ),
            ),
          ),
        const SizedBox(width: CalendarWeekRow.summaryWidth + 8),
      ],
    );
  }

  List<Widget> _weekRows(DateTime monthDate, int daysInMonth, WeekMax globalMax) {
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
        unitSystem: unitSystem,
        onDateTap: onDateTap,
      );
    });
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Text('No activity yet', style: AppTypography.caption),
      ),
    );
  }
}
