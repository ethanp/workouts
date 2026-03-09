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
import 'package:workouts/widgets/run_trend_chart.dart';
import 'package:workouts/widgets/weekly_bar_chart.dart';
import 'package:workouts/widgets/weekly_stacked_zone_chart.dart';
import 'package:workouts/widgets/zoomable_chart_area.dart';

class HistoryChartsTab extends ConsumerWidget {
  const HistoryChartsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final runsAsync = ref.watch(runsStreamProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final fullRange = ref.watch(chartDateRangeProvider);
    final visibleRange = ref.watch(chartZoomProvider) ?? fullRange;

    return calendarAsync.when(
      data: (days) {
        final chartList = _chartList(
          days, runsAsync.value ?? [], unitSystem, visibleRange,
        );
        if (fullRange == null) return chartList;

        final isZoomed = visibleRange != null && visibleRange != fullRange;
        return ZoomableChartArea(
          fullRange: fullRange,
          child: Stack(
            children: [
              chartList,
              if (isZoomed) _zoomResetPill(ref),
            ],
          ),
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load data: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _chartList(
    List<ActivityCalendarDay> days,
    List<FitnessRun> runs,
    UnitSystem unitSystem,
    DateTimeRange? visibleRange,
  ) {
    final weeklyAggregates = _aggregateByWeek(days);
    final distanceUnit = unitSystem == UnitSystem.imperial ? 'mi' : 'km';
    final metersPerUnit = unitSystem == UnitSystem.imperial
        ? metersPerMile
        : 1000.0;

    final visibleWeeks = visibleRange != null
        ? _filterWeeksToRange(weeklyAggregates, visibleRange)
        : weeklyAggregates;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _FourWeekSummary(days: days, unitSystem: unitSystem),
        const SizedBox(height: AppSpacing.lg),
        FitnessMomentumChart(
          days: days,
          displayStart: visibleRange?.start,
          displayEnd: visibleRange?.end,
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Distance',
          weeks: _weekDataList(
            visibleWeeks,
            valueFor: (week) => week.totalRunMeters / metersPerUnit,
          ),
          barColor: AppColors.accentPrimary,
          formatValue: (value) => '${value.toStringAsFixed(1)}$distanceUnit',
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Activity Days',
          weeks: _weekDataList(
            visibleWeeks,
            valueFor: (week) => week.activeDays.toDouble(),
          ),
          barColor: const Color(0xFF64D2FF),
          formatValue: (value) => '${value.round()}d',
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyStackedZoneChart(
          weeks: _weekZoneDataList(visibleWeeks),
        ),
        const SizedBox(height: AppSpacing.lg),
        RunTrendChart(
          title: 'Run Trends',
          series: _runTrendSeries(runs, unitSystem),
          displayStart: visibleRange?.start,
          displayEnd: visibleRange?.end,
        ),
      ],
    );
  }

  Widget _zoomResetPill(WidgetRef ref) {
    return Positioned(
      top: AppSpacing.md,
      right: AppSpacing.md,
      child: GestureDetector(
        onTap: () => ref.read(chartZoomProvider.notifier).reset(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderDepth1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.arrow_left_right,
                size: 12,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                'Reset zoom',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentPrimary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<WeekAggregate> _filterWeeksToRange(
    List<WeekAggregate> aggregates,
    DateTimeRange range,
  ) {
    final rangeEnd = range.end.add(const Duration(days: 7));
    return aggregates
        .where((week) =>
            !week.weekStart.isBefore(range.start) &&
            week.weekStart.isBefore(rangeEnd))
        .toList();
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

  List<WeekZoneData> _weekZoneDataList(List<WeekAggregate> aggregates) {
    return aggregates
        .map(
          (aggregate) => WeekZoneData(
            label: aggregate.label,
            weekStart: aggregate.weekStart,
            zone1Minutes: aggregate.zone1Minutes,
            zone2Minutes: aggregate.zone2Minutes,
            zone3Minutes: aggregate.zone3Minutes,
            zone4Minutes: aggregate.zone4Minutes,
            zone5Minutes: aggregate.zone5Minutes,
            isCurrent: aggregate.isCurrent,
            includeInAverage: !aggregate.beforeData,
          ),
        )
        .toList();
  }

  List<TrendSeries> _runTrendSeries(
    List<FitnessRun> runs,
    UnitSystem unitSystem,
  ) {
    final sortedRuns = _chronologicalRuns(runs);
    final metersPerUnit = _metersPerUnit(unitSystem);
    final distanceUnit = _distanceUnitLabel(unitSystem);
    return [
      _paceSeries(sortedRuns, metersPerUnit),
      _distanceSeries(sortedRuns, metersPerUnit, distanceUnit),
      _avgHrSeries(sortedRuns),
      _maxHrSeries(sortedRuns),
      _caloriesSeries(sortedRuns),
      _durationSeries(sortedRuns),
    ];
  }

  List<FitnessRun> _chronologicalRuns(List<FitnessRun> runs) {
    return runs
        .where((run) => run.durationSeconds > 0)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  double _metersPerUnit(UnitSystem unitSystem) =>
      unitSystem == UnitSystem.imperial ? metersPerMile : 1000.0;

  String _distanceUnitLabel(UnitSystem unitSystem) =>
      unitSystem == UnitSystem.imperial ? 'mi' : 'km';

  TrendSeries _paceSeries(List<FitnessRun> runs, double metersPerUnit) {
    final paceRuns = runs.where((r) => r.distanceMeters >= metersPerMile);
    return TrendSeries(
      label: 'Pace',
      color: AppColors.accentPrimary,
      invertY: true,
      points: paceRuns
          .map((r) => TrendPoint(
                date: r.startedAt,
                value: r.durationSeconds / (r.distanceMeters / metersPerUnit),
              ))
          .toList(),
      formatValue: (v) => Format.paceValue(v),
    );
  }

  TrendSeries _distanceSeries(
    List<FitnessRun> runs,
    double metersPerUnit,
    String unitLabel,
  ) {
    return TrendSeries(
      label: 'Distance',
      color: const Color(0xFF30D158),
      points: runs
          .map((r) => TrendPoint(
                date: r.startedAt,
                value: r.distanceMeters / metersPerUnit,
              ))
          .toList(),
      formatValue: (v) => '${v.toStringAsFixed(1)}$unitLabel',
    );
  }

  TrendSeries _avgHrSeries(List<FitnessRun> runs) {
    return TrendSeries(
      label: 'Avg HR',
      color: const Color(0xFFFF453A),
      points: runs
          .where((r) => r.averageHeartRateBpm != null)
          .map((r) => TrendPoint(
                date: r.startedAt,
                value: r.averageHeartRateBpm!,
              ))
          .toList(),
      formatValue: (v) => '${v.round()} bpm',
    );
  }

  TrendSeries _maxHrSeries(List<FitnessRun> runs) {
    return TrendSeries(
      label: 'Max HR',
      color: const Color(0xFFFF6961),
      points: runs
          .where((r) => r.maxHeartRateBpm != null)
          .map((r) => TrendPoint(
                date: r.startedAt,
                value: r.maxHeartRateBpm!,
              ))
          .toList(),
      formatValue: (v) => '${v.round()} bpm',
    );
  }

  TrendSeries _caloriesSeries(List<FitnessRun> runs) {
    return TrendSeries(
      label: 'Calories',
      color: const Color(0xFFFFD60A),
      points: runs
          .where((r) => r.energyKcal != null)
          .map((r) => TrendPoint(
                date: r.startedAt,
                value: r.energyKcal!,
              ))
          .toList(),
      formatValue: (v) => '${v.round()} kcal',
    );
  }

  TrendSeries _durationSeries(List<FitnessRun> runs) {
    return TrendSeries(
      label: 'Duration',
      color: const Color(0xFF64D2FF),
      points: runs
          .map((r) => TrendPoint(
                date: r.startedAt,
                value: r.durationSeconds.toDouble(),
              ))
          .toList(),
      formatValue: (v) => Format.durationShort(v.round()),
    );
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
      aggregate.zone1Minutes += day.totalZone1Minutes;
      aggregate.zone2Minutes += day.totalZone2Minutes;
      aggregate.zone3Minutes += day.totalZone3Minutes;
      aggregate.zone4Minutes += day.totalZone4Minutes;
      aggregate.zone5Minutes += day.totalZone5Minutes;
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
  int zone1Minutes = 0;
  int zone2Minutes = 0;
  int zone3Minutes = 0;
  int zone4Minutes = 0;
  int zone5Minutes = 0;
  int activeDays = 0;

  int get gteZone2Minutes =>
      zone2Minutes + zone3Minutes + zone4Minutes + zone5Minutes;
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
    var totalGteZone2 = 0;
    var activityDayCount = 0;

    for (final day in recentDays) {
      totalMeters += day.totalRunDistanceMeters;
      totalRunSeconds += day.totalRunDurationSeconds;
      totalSessionMinutes += day.totalSessionDurationSeconds ~/ 60;
      totalGteZone2 += day.totalGteZone2Minutes;
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
                'distance',
                '${distance.toStringAsFixed(1)}$distanceUnit',
              ),
              _statCell(
                'run time',
                runHours > 0 ? '${runHours}h ${runMinutes}m' : '${runMinutes}m',
              ),
              _statCell('active days', '$activityDayCount'),
              _statCell('>= zone 2', '${totalGteZone2}m'),
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

  Widget _statCell(String label, String value) {
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
