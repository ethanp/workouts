import 'dart:math' as math;

import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';

class WeeklyActivityAggregator {
  List<WeekAggregate> aggregate(
    List<ActivityCalendarDay> days,
    List<CardioWorkout> workouts,
  ) {
    final weeklyAggregates = aggregateByWeek(days);
    addCardioTypeBreakdown(weeklyAggregates, workouts);
    return weeklyAggregates;
  }

  static DateTime mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  List<WeekAggregate> aggregateByWeek(List<ActivityCalendarDay> days) {
    final currentMonday = mondayOf(DateTime.now());
    final earliestMonday = earliestActivityMonday(days) ?? currentMonday;

    final weekCount = math.max(
      1,
      (currentMonday.difference(earliestMonday).inDays ~/ 7) + 1,
    );

    final byMonday = <DateTime, WeekAggregate>{};
    for (var weekIndex = 0; weekIndex < weekCount; weekIndex++) {
      final monday = DateTime(
        currentMonday.year,
        currentMonday.month,
        currentMonday.day - 7 * (weekCount - 1 - weekIndex),
      );
      byMonday[monday] = WeekAggregate(
        label: '${monday.month}/${monday.day}',
        weekStart: monday,
        isCurrent: weekIndex == weekCount - 1,
        beforeData: monday.isBefore(earliestMonday),
      );
    }

    for (final day in days) {
      if (!day.hasActivity) continue;
      final monday = mondayOf(day.date);
      final aggregate = byMonday[monday];
      if (aggregate == null) continue;
      aggregate.outdoorRunMeters += day.outdoorRunDistanceMeters;
      aggregate.zoneTime = aggregate.zoneTime + day.totalZoneTime;
      aggregate.activeDays++;
    }

    return byMonday.values.toList();
  }

  void addCardioTypeBreakdown(
    List<WeekAggregate> weeklyAggregates,
    List<CardioWorkout> workouts,
  ) {
    final aggregatesByMonday = {
      for (final weeklyAggregate in weeklyAggregates)
        weeklyAggregate.weekStart: weeklyAggregate,
    };
    for (final workout in workouts) {
      final monday = mondayOf(workout.startedAt);
      final weeklyAggregate = aggregatesByMonday[monday];
      if (weeklyAggregate == null) continue;
      weeklyAggregate.cardioWorkoutCountsByType.update(
        workout.activityType,
        (workoutCount) => workoutCount + 1,
        ifAbsent: () => 1,
      );
    }
  }

  DateTime? earliestActivityMonday(List<ActivityCalendarDay> days) {
    DateTime? earliest;
    for (final day in days) {
      if (!day.hasActivity) continue;
      if (earliest == null || day.date.isBefore(earliest)) earliest = day.date;
    }
    if (earliest == null) return null;
    return mondayOf(earliest);
  }
}

class WeekAggregate {
  WeekAggregate({
    required this.label,
    required this.weekStart,
    this.isCurrent = false,
    this.beforeData = false,
  });

  final String label;
  final DateTime weekStart;
  final bool isCurrent;
  final bool beforeData;
  double outdoorRunMeters = 0;
  HrZoneTime zoneTime = HrZoneTime.zero;
  int activeDays = 0;
  final Map<CardioType, int> cardioWorkoutCountsByType = {};

  List<CardioType> get cardioWorkoutTypes => CardioType.values.whereL(
    (cardioType) => cardioWorkoutCountsByType.containsKey(cardioType),
  );
}
