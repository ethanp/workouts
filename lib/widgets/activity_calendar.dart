import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';

const double _cellSize = 39;
const double _cellMargin = 2;
const double _summaryWidth = 60;
const double _daysBadgeWidth = 18;
const double _summaryFontSize = 10;
const int _daysPerWeek = 7;

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

  static const _metersPerMile = 1609.344;

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

  Widget _header() => const Text('Activity Calendar', style: AppTypography.subtitle);

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
          color: _intensityColor(intensity),
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

  _WeekMax _computeGlobalMax() {
    double maxRunMeters = 0;
    int maxSessionMinutes = 0;
    for (final entry in activityData.entries) {
      if (!entry.value.hasActivity) continue;
      maxRunMeters = math.max(maxRunMeters, entry.value.totalRunDistanceMeters);
      final sessionMinutes = entry.value.totalSessionDurationSeconds ~/ 60;
      maxSessionMinutes = math.max(maxSessionMinutes, sessionMinutes);
    }
    return _WeekMax(maxRunMeters: maxRunMeters, maxSessionMinutes: maxSessionMinutes);
  }

  List<Widget> _buildMonths(_WeekMax globalMax) {
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

  Widget _monthWidget(
    DateTime monthDate,
    int daysInMonth,
    _WeekMax globalMax,
  ) {
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
    _WeekMax globalMax,
  ) {
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday;
    final totalDays = firstWeekday - 1 + daysInMonth;
    final weeksInMonth = (totalDays / _daysPerWeek).ceil();

    return List.generate(weeksInMonth, (week) {
      return _buildWeekRow(
          monthDate, daysInMonth, week, firstWeekday, globalMax);
    });
  }

  Widget _buildWeekRow(
    DateTime monthDate,
    int daysInMonth,
    int week,
    int firstWeekday,
    _WeekMax globalMax,
  ) {
    final cells = <Widget>[];
    var activeDays = 0;
    var weekRunMeters = 0.0;
    var weekSessionMinutes = 0;
    var weekZone2Minutes = 0;
    var weekHasHrData = false;
    var ownsWeek = false;

    for (var day = 0; day < _daysPerWeek; day++) {
      final dayOffset = week * _daysPerWeek + day - (firstWeekday - 1);
      final isInMonth = dayOffset >= 0 && dayOffset < daysInMonth;

      if (isInMonth) {
        final date = DateTime(monthDate.year, monthDate.month, dayOffset + 1);
        if (day == 6) ownsWeek = true;
        cells.add(_dayCell(date, globalMax));
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
          _weekSummary(
            ownsWeek: ownsWeek,
            activeDays: activeDays,
            runMeters: weekRunMeters,
            sessionMinutes: weekSessionMinutes,
            zone2Minutes: weekZone2Minutes,
            hasHrData: weekHasHrData,
            globalMax: globalMax,
          ),
        ],
      ),
    );
  }

  Widget _weekSummary({
    required bool ownsWeek,
    required int activeDays,
    required double runMeters,
    required int sessionMinutes,
    required int zone2Minutes,
    required bool hasHrData,
    required _WeekMax globalMax,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SizedBox(
        width: _summaryWidth,
        child: ownsWeek && activeDays > 0
            ? _weekSummaryContent(
                activeDays: activeDays,
                runMeters: runMeters,
                sessionMinutes: sessionMinutes,
                zone2Minutes: zone2Minutes,
                hasHrData: hasHrData,
                globalMax: globalMax,
              )
            : null,
      ),
    );
  }

  Widget _weekSummaryContent({
    required int activeDays,
    required double runMeters,
    required int sessionMinutes,
    required int zone2Minutes,
    required bool hasHrData,
    required _WeekMax globalMax,
  }) {
    final intensity = _intensityForDay(
      runMeters: runMeters,
      sessionMinutes: sessionMinutes,
      globalMax: globalMax,
    );
    final parts = <String>[];
    if (runMeters > 0) parts.add(_formatDistanceShort(runMeters));
    if (sessionMinutes > 0) parts.add('${sessionMinutes}m');
    final summaryLabel = parts.isEmpty ? '' : parts.join(' · ');
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
                summaryLabel,
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

  double _intensityForDay({
    required double runMeters,
    required int sessionMinutes,
    required _WeekMax globalMax,
  }) {
    if (runMeters > 0 && globalMax.maxRunMeters > 0) {
      return (runMeters / globalMax.maxRunMeters).clamp(0.0, 1.0);
    }
    if (sessionMinutes > 0 && globalMax.maxSessionMinutes > 0) {
      return (sessionMinutes / globalMax.maxSessionMinutes)
          .clamp(0.0, 1.0)
          * 0.5;
    }
    return 0.0;
  }

  Widget _dayCell(DateTime date, _WeekMax globalMax) {
    final entry = activityData[date];
    final hasActivity = entry?.hasActivity ?? false;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final intensity = hasActivity
        ? _intensityForDay(
            runMeters: entry!.totalRunDistanceMeters,
            sessionMinutes: entry.totalSessionDurationSeconds ~/ 60,
            globalMax: globalMax,
          )
        : 0.0;
    final cellColor = hasActivity
        ? _intensityColor(intensity)
        : AppColors.backgroundDepth3.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: () => onDateTap(date),
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
    ActivityCalendarDay? entry,
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

    final parts = <String>[];
    if (entry!.totalRunDistanceMeters > 0) {
      parts.add(_formatDistanceCell(entry.totalRunDistanceMeters));
    }
    if (entry.totalSessionDurationSeconds > 0) {
      parts.add('${entry.totalSessionDurationSeconds ~/ 60}m');
    }
    final label = parts.isEmpty ? '-' : parts.join(' · ');

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
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (entry.runHasHrData && entry.runZone2Minutes > 0)
                Text(
                  '${entry.runZone2Minutes}z',
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
        child: Text('No activity yet', style: AppTypography.caption),
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

  String _formatDistanceCell(double meters) {
    if (unitSystem == UnitSystem.imperial) {
      final miles = meters / _metersPerMile;
      if (miles >= 10) return '${miles.round()}mi';
      return '${miles.toStringAsFixed(1)}mi';
    }
    final km = meters / 1000;
    if (km >= 10) return '${km.round()}km';
    return '${km.toStringAsFixed(1)}km';
  }

  String _formatDistanceShort(double meters) {
    if (unitSystem == UnitSystem.imperial) {
      final miles = meters / _metersPerMile;
      return miles >= 10
          ? '${miles.round()}mi'
          : '${miles.toStringAsFixed(1)}mi';
    }
    final km = meters / 1000;
    return km >= 10 ? '${km.round()}km' : '${km.toStringAsFixed(1)}km';
  }
}

class _WeekMax {
  _WeekMax({required this.maxRunMeters, required this.maxSessionMinutes});
  final double maxRunMeters;
  final int maxSessionMinutes;
}
