import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/providers/activity_provider.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/fitness_momentum_chart.dart';
import 'package:workouts/widgets/pace_trend_chart.dart';
import 'package:workouts/widgets/weekly_bar_chart.dart';

class HistoryChartsTab extends ConsumerWidget {
  const HistoryChartsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final runsAsync = ref.watch(runsStreamProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final chartRange = ref.watch(chartDateRangeProvider);

    return calendarAsync.when(
      data: (days) =>
          _buildCharts(days, runsAsync.value ?? [], unitSystem, chartRange),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load data: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildCharts(
    List<ActivityCalendarDay> days,
    List<FitnessRun> runs,
    UnitSystem unitSystem,
    DateTimeRange? chartRange,
  ) {
    final weeklyAggregates = _aggregateByWeek(days);
    final distanceUnit = unitSystem == UnitSystem.imperial ? 'mi' : 'km';
    final metersPerUnit = unitSystem == UnitSystem.imperial
        ? metersPerMile
        : 1000.0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _FourWeekSummary(days: days, unitSystem: unitSystem),
        const SizedBox(height: AppSpacing.lg),
        FitnessMomentumChart(
          days: days,
          displayStart: chartRange?.start,
          displayEnd: chartRange?.end,
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Distance',
          weeks: _weekDataList(
            weeklyAggregates,
            valueFor: (week) => week.totalRunMeters / metersPerUnit,
          ),
          barColor: AppColors.accentPrimary,
          formatValue: (value) => '${value.toStringAsFixed(1)}$distanceUnit',
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Activity Days',
          weeks: _weekDataList(
            weeklyAggregates,
            valueFor: (week) => week.activeDays.toDouble(),
          ),
          barColor: const Color(0xFF64D2FF),
          formatValue: (value) => '${value.round()}d',
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Zone 2',
          weeks: _weekDataList(
            weeklyAggregates,
            valueFor: (week) => week.zone2Minutes.toDouble(),
          ),
          barColor: const Color(0xFF30D158),
          formatValue: (value) => '${value.round()}m',
        ),
        const SizedBox(height: AppSpacing.lg),
        PaceTrendChart(
          title: '1 Mi Pace',
          points: _pacePoints(runs, unitSystem),
          unitLabel: unitSystem == UnitSystem.imperial ? 'mi' : 'km',
          displayStart: chartRange?.start,
          displayEnd: chartRange?.end,
        ),
      ],
    );
  }

  List<WeekData> _weekDataList(
    List<WeekAggregate> aggregates, {
    required double Function(WeekAggregate) valueFor,
  }) {
    return aggregates
        .map(
          (aggregate) => WeekData(
            label: aggregate.label,
            value: valueFor(aggregate),
            weekStart: aggregate.weekStart,
            isCurrent: aggregate.isCurrent,
            includeInAverage: !aggregate.beforeData,
          ),
        )
        .toList();
  }

  List<PacePoint> _pacePoints(List<FitnessRun> runs, UnitSystem unitSystem) {
    final qualifyingRuns =
        runs
            .where(
              (run) =>
                  run.distanceMeters >= metersPerMile &&
                  run.durationSeconds > 0,
            )
            .toList()
          ..sort((runA, runB) => runA.startedAt.compareTo(runB.startedAt));

    final metersPerUnit = unitSystem == UnitSystem.imperial
        ? metersPerMile
        : 1000.0;

    return qualifyingRuns
        .map(
          (run) => PacePoint(
            date: run.startedAt,
            paceSecondsPerUnit:
                run.durationSeconds / (run.distanceMeters / metersPerUnit),
          ),
        )
        .toList();
  }

  static DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  List<WeekAggregate> _aggregateByWeek(List<ActivityCalendarDay> days) {
    final currentMonday = _mondayOf(DateTime.now());
    final earliestMonday = _earliestActivityMonday(days) ?? currentMonday;

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

    for (final ActivityCalendarDay day in days) {
      if (!day.hasActivity) continue;
      final monday = _mondayOf(day.date);
      final aggregate = byMonday[monday]!;
      aggregate.totalRunMeters += day.totalRunDistanceMeters;
      aggregate.zone2Minutes += day.totalZone2Minutes;
      aggregate.activeDays++;
    }

    return byMonday.values.toList();
  }

  DateTime? _earliestActivityMonday(List<ActivityCalendarDay> days) {
    DateTime? earliest;
    for (final day in days) {
      if (!day.hasActivity) continue;
      if (earliest == null || day.date.isBefore(earliest)) earliest = day.date;
    }
    if (earliest == null) return null;
    return _mondayOf(earliest);
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
  double totalRunMeters = 0;
  int zone2Minutes = 0;
  int activeDays = 0;
}

class _FourWeekSummary extends StatelessWidget {
  const _FourWeekSummary({required this.days, required this.unitSystem});

  final List<ActivityCalendarDay> days;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));
    final recentDays = days.where(
      (day) => day.date.isAfter(fourWeeksAgo) && day.hasActivity,
    );

    var totalMeters = 0.0;
    var totalRunSeconds = 0;
    var totalSessionMinutes = 0;
    var totalZone2 = 0;
    var activityDayCount = 0;

    for (final day in recentDays) {
      totalMeters += day.totalRunDistanceMeters;
      totalRunSeconds += day.totalRunDurationSeconds;
      totalSessionMinutes += day.totalSessionDurationSeconds ~/ 60;
      totalZone2 += day.totalZone2Minutes;
      activityDayCount++;
    }

    final metersPerUnit = unitSystem == UnitSystem.imperial
        ? metersPerMile
        : 1000.0;
    final distanceUnit = unitSystem == UnitSystem.imperial ? 'mi' : 'km';
    final distance = totalMeters / metersPerUnit;
    final runHours = totalRunSeconds ~/ 3600;
    final runMinutes = (totalRunSeconds % 3600) ~/ 60;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 4 Weeks', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _statCell(
                '${distance.toStringAsFixed(1)}$distanceUnit',
                'distance',
              ),
              _statCell(
                runHours > 0 ? '${runHours}h ${runMinutes}m' : '${runMinutes}m',
                'run time',
              ),
              _statCell('$activityDayCount', 'active days'),
              _statCell('${totalZone2}m', 'zone 2'),
            ],
          ),
          if (totalSessionMinutes > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${totalSessionMinutes}m session time',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCell(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.subtitle.copyWith(color: AppColors.textColor1),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor4,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
