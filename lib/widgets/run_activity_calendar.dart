import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/run_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

const double _cellSize = 39;
const double _cellMargin = 2;
const double _summaryWidth = 60;
const double _daysBadgeWidth = 18;
const double _summaryFontSize = 10;
const int _daysPerWeek = 7;

class RunActivityCalendar extends StatefulWidget {
  const RunActivityCalendar({
    super.key,
    required this.activityData,
    required this.unitSystem,
    required this.onDateTap,
  });

  final Map<DateTime, RunCalendarDay> activityData;
  final UnitSystem unitSystem;
  final void Function(DateTime date) onDateTap;

  @override
  State<RunActivityCalendar> createState() => _RunActivityCalendarState();
}

class _RunActivityCalendarState extends State<RunActivityCalendar> {

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
          _header(),
          const SizedBox(height: AppSpacing.sm),
          _legend(),
          const SizedBox(height: AppSpacing.md),
          _grid(),
        ],
      ),
    );
  }

  Widget _header() => const Text('Run Calendar', style: AppTypography.subtitle);

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
          widget.unitSystem == UnitSystem.imperial ? 'mi / z2 min' : 'km / z2 min',
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
          color: _intensityColor(intensity),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    });
  }

  Widget _grid() {
    if (widget.activityData.isEmpty) return _emptyState();

    final globalMaxMeters = _computeGlobalMaxMeters();
    final months = _buildMonths(globalMaxMeters);
    if (months.isEmpty) return _emptyState();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: months,
      ),
    );
  }

  double _computeGlobalMaxMeters() {
    final weekSums = <int, double>{};
    for (final entry in widget.activityData.entries) {
      if (!entry.value.hasActivity) continue;
      final weekKey = _isoWeekKey(entry.key);
      weekSums.update(
        weekKey,
        (sum) => sum + entry.value.totalDistanceMeters,
        ifAbsent: () => entry.value.totalDistanceMeters,
      );
    }
    return weekSums.values.fold(0.0, math.max);
  }

  int _isoWeekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return monday.year * 10000 + monday.month * 100 + monday.day;
  }

  List<Widget> _buildMonths(double globalMaxMeters) {
    if (widget.activityData.isEmpty) return [];

    final oldest = widget.activityData.keys.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    final now = DateTime.now();
    final months = <Widget>[];

    var cursor = DateTime(oldest.year, oldest.month, 1);
    final endMonth = DateTime(now.year, now.month, 1);

    while (!cursor.isAfter(endMonth)) {
      final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
      if (_monthHasActivity(cursor, daysInMonth)) {
        months.add(_monthWidget(cursor, daysInMonth, globalMaxMeters));
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  bool _monthHasActivity(DateTime monthDate, int daysInMonth) {
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final entry = widget.activityData[date];
      if (entry != null && entry.hasActivity) return true;
    }
    return false;
  }

  Widget _monthWidget(
    DateTime monthDate,
    int daysInMonth,
    double globalMaxMeters,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _monthHeader(monthDate),
        _dayOfWeekRow(),
        ..._weekRows(monthDate, daysInMonth, globalMaxMeters),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _monthHeader(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${months[date.month - 1]} ${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 4),
      child: Text(
        label,
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
            width: _cellSize + _cellMargin * 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
                fontSize: 9,
              ),
            ),
          ),
        const SizedBox(width: _summaryWidth + 8),
      ],
    );
  }

  List<Widget> _weekRows(
    DateTime monthDate,
    int daysInMonth,
    double globalMaxMeters,
  ) {
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday;
    final totalDays = firstWeekday - 1 + daysInMonth;
    final weeksInMonth = (totalDays / _daysPerWeek).ceil();

    return List.generate(weeksInMonth, (week) {
      return _buildWeekRow(
          monthDate, daysInMonth, week, firstWeekday, globalMaxMeters);
    });
  }

  Widget _buildWeekRow(
    DateTime monthDate,
    int daysInMonth,
    int week,
    int firstWeekday,
    double globalMaxMeters,
  ) {
    final cells = <Widget>[];
    var activeDays = 0;
    var weekTotalMeters = 0.0;
    var weekZone2Minutes = 0;
    var weekHasHrData = false;
    var ownsWeek = false;

    for (var day = 0; day < _daysPerWeek; day++) {
      final dayOffset = week * _daysPerWeek + day - (firstWeekday - 1);
      final isInMonth = dayOffset >= 0 && dayOffset < daysInMonth;

      if (isInMonth) {
        final date = DateTime(monthDate.year, monthDate.month, dayOffset + 1);
        if (day == 6) ownsWeek = true;
        cells.add(_dayCell(date, globalMaxMeters));
      } else {
        cells.add(_emptyCell());
      }
    }

    if (ownsWeek) {
      final sundayOffset = week * _daysPerWeek + 6 - (firstWeekday - 1);
      final sunday = DateTime(monthDate.year, monthDate.month, sundayOffset + 1);
      final monday = sunday.subtract(const Duration(days: 6));
      for (var i = 0; i < _daysPerWeek; i++) {
        final date = monday.add(Duration(days: i));
        final entry = widget.activityData[date];
        if (entry != null && entry.hasActivity) {
          activeDays++;
          weekTotalMeters += entry.totalDistanceMeters;
          weekZone2Minutes += entry.zone2Minutes;
          if (entry.hasHrData) weekHasHrData = true;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...cells,
          _weekSummary(
            ownsWeek: ownsWeek,
            activeDays: activeDays,
            totalMeters: weekTotalMeters,
            zone2Minutes: weekZone2Minutes,
            hasHrData: weekHasHrData,
            globalMaxMeters: globalMaxMeters,
          ),
        ],
      ),
    );
  }

  Widget _weekSummary({
    required bool ownsWeek,
    required int activeDays,
    required double totalMeters,
    required int zone2Minutes,
    required bool hasHrData,
    required double globalMaxMeters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: _summaryWidth,
        child: ownsWeek && activeDays > 0
            ? _weekSummaryContent(
                activeDays: activeDays,
                totalMeters: totalMeters,
                zone2Minutes: zone2Minutes,
                hasHrData: hasHrData,
                globalMaxMeters: globalMaxMeters,
              )
            : null,
      ),
    );
  }

  Widget _weekSummaryContent({
    required int activeDays,
    required double totalMeters,
    required int zone2Minutes,
    required bool hasHrData,
    required double globalMaxMeters,
  }) {
    final intensity =
        globalMaxMeters > 0 ? (totalMeters / globalMaxMeters).clamp(0.0, 1.0) : 0.0;
    final distanceLabel = Format.distanceCompact(totalMeters, widget.unitSystem);
    final summaryColor = CupertinoColors.white.withValues(
      alpha: 0.4 + intensity * 0.6,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _daysBadge(activeDays),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                distanceLabel,
                style: TextStyle(
                  fontSize: _summaryFontSize,
                  fontWeight: intensity > 0.5
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: summaryColor,
                ),
              ),
              if (hasHrData && zone2Minutes > 0)
                Text(
                  '${zone2Minutes}z',
                  style: TextStyle(
                    fontSize: _summaryFontSize - 1,
                    color: AppColors.textColor4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _daysBadge(int activeDays) {
    final intensity = activeDays / _daysPerWeek;
    return SizedBox(
      width: _daysBadgeWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: _intensityColor(intensity * 0.7),
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

  Widget _dayCell(DateTime date, double globalMaxMeters) {
    final entry = widget.activityData[date];
    final hasActivity = entry?.hasActivity ?? false;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final intensity = (hasActivity && globalMaxMeters > 0)
        ? (entry!.totalDistanceMeters / globalMaxMeters).clamp(0.0, 1.0)
        : 0.0;
    final cellColor = hasActivity
        ? _intensityColor(intensity)
        : AppColors.backgroundDepth3.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: () => widget.onDateTap(date),
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.all(_cellMargin),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isToday
                ? AppColors.accentPrimary
                : hasActivity
                    ? _intensityColor(intensity).withValues(alpha: 0.6)
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
        child: _dayCellContent(date, entry, hasActivity, intensity),
      ),
    );
  }

  Widget _dayCellContent(
    DateTime date,
    RunCalendarDay? entry,
    bool hasActivity,
    double intensity,
  ) {
    if (!hasActivity) {
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

    final textColor = intensity > 0.5
        ? CupertinoColors.black.withValues(alpha: 0.8)
        : CupertinoColors.white;

    return Stack(
      children: [
        Positioned(
          left: 3,
          top: 2,
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Format.distanceCompact(entry!.totalDistanceMeters, widget.unitSystem),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (entry.hasHrData && entry.zone2Minutes > 0)
                Text(
                  '${entry.zone2Minutes}z',
                  style: TextStyle(
                    fontSize: 8,
                    color: textColor.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyCell() {
    return const SizedBox(
      width: _cellSize,
      height: _cellSize,
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Text('No runs yet', style: AppTypography.caption),
      ),
    );
  }

  Color _intensityColor(double intensity) {
    return Color.lerp(
      AppColors.accentPrimary.withValues(alpha: 0.15),
      AppColors.accentPrimary.withValues(alpha: 0.9),
      intensity,
    )!;
  }

}
