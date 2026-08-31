import 'dart:math' as math;

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/models/activity_calendar_day.dart';

class const TrailingSevenDayTotals() {
  static const _smoothingHalfWindow = 3;
  static const _smoothingPasses = 2;

  List<RollingDailyPoint> build({
    required List<ActivityCalendarDay> days,
    required DateTime endDate,
    required double Function(ActivityCalendarDay day) dailyValue,
  }) {
    if (days.isEmpty) return [];

    final valueByDate = _valueByDate(days, dailyValue);
    if (valueByDate.isEmpty) return [];

    final firstChartDate = _firstChartDate(days, endDate);
    final chartDates = _calendarDates(firstChartDate, endDate.startOfDay);
    final rawPoints = chartDates.mapL(
      (chartDate) => RollingDailyPoint(
        date: chartDate,
        rollingValue: _rollingSevenDayTotal(chartDate, valueByDate),
        smoothedValue: 0,
      ),
    );

    return _doubleSmoothedPoints(rawPoints);
  }

  Map<DateTime, double> _valueByDate(
    List<ActivityCalendarDay> days,
    double Function(ActivityCalendarDay day) dailyValue,
  ) {
    final valueByDate = <DateTime, double>{};
    for (final activityDay in days) {
      if (!activityDay.hasActivity) continue;
      valueByDate[activityDay.date.startOfDay] = dailyValue(activityDay);
    }
    return valueByDate;
  }

  DateTime _firstChartDate(List<ActivityCalendarDay> days, DateTime endDate) {
    DateTime? firstActivityDate;
    for (final activityDay in days) {
      if (!activityDay.hasActivity) continue;
      final activityDate = activityDay.date.startOfDay;
      if (firstActivityDate == null ||
          activityDate.isBefore(firstActivityDate)) {
        firstActivityDate = activityDate;
      }
    }
    return firstActivityDate ?? endDate.startOfDay;
  }

  List<DateTime> _calendarDates(DateTime firstDate, DateTime endDate) {
    final normalizedFirstDate = firstDate.startOfDay;
    final normalizedEndDate = endDate.startOfDay;
    if (normalizedFirstDate.isAfter(normalizedEndDate)) return [];

    final dateCount =
        normalizedEndDate.difference(normalizedFirstDate).inDays + 1;
    return List.generate(
      dateCount,
      (dayOffset) => normalizedFirstDate.shiftedByDays(dayOffset),
    );
  }

  double _rollingSevenDayTotal(
    DateTime date,
    Map<DateTime, double> valueByDate,
  ) {
    var rollingTotal = 0.0;
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final windowDate = date.shiftedByDays(-dayOffset);
      rollingTotal += valueByDate[windowDate] ?? 0;
    }
    return rollingTotal;
  }

  List<RollingDailyPoint> _doubleSmoothedPoints(
    List<RollingDailyPoint> rawPoints,
  ) {
    var smoothedValues = rawPoints.mapL((point) => point.rollingValue);
    for (var pass = 0; pass < _smoothingPasses; pass++) {
      smoothedValues = _centeredMovingAverage(smoothedValues);
    }

    return rawPoints.mapLWithIndex(
      (rawPoint, pointIndex) => RollingDailyPoint(
        date: rawPoint.date,
        rollingValue: rawPoint.rollingValue,
        smoothedValue: smoothedValues[pointIndex],
      ),
    );
  }

  List<double> _centeredMovingAverage(List<double> values) =>
      List.generate(values.length, (index) => _windowAverage(values, index));

  double _windowAverage(List<double> values, int index) {
    final firstIndex = math.max(0, index - _smoothingHalfWindow);
    final lastIndex = math.min(values.length - 1, index + _smoothingHalfWindow);
    var total = 0.0;
    for (
      var neighborIndex = firstIndex;
      neighborIndex <= lastIndex;
      neighborIndex++
    ) {
      total += values[neighborIndex];
    }
    return total / (lastIndex - firstIndex + 1);
  }
}
