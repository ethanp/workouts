import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/cardio_type_palette.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/cardio_trend_chart.dart';
import 'package:workouts/features/history/charts/cardio_trend_series_factory.dart';
import 'package:workouts/features/history/charts/polarization_chart.dart';
import 'package:workouts/features/history/charts/week_zone_data.dart';
import 'package:workouts/features/history/training_balance_strip.dart';
import 'package:workouts/features/history/charts/weekly_activity_aggregator.dart';
import 'package:workouts/features/history/charts/weekly_bar_chart.dart';
import 'package:workouts/widgets/zoomable_chart_area.dart';

class HistoryChartsTab extends ConsumerWidget {
  const HistoryChartsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final cardioWorkoutsAsync = ref.watch(cardioWorkoutsProvider);
    final bestEffortsAsync = ref.watch(cardioBestEffortsProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final fullRange = ref.watch(chartDateRangeProvider);
    final visibleRange = ref.watch(chartZoomProvider) ?? fullRange;

    return calendarAsync.when(
      data: (days) {
        final chartList = _chartList(
          days,
          cardioWorkoutsAsync.value ?? [],
          bestEffortsAsync.value ?? [],
          unitSystem,
          visibleRange,
        );
        if (fullRange == null) return chartList;

        final isZoomed = visibleRange != null && visibleRange != fullRange;
        return ZoomableChartArea(
          fullRange: fullRange,
          child: Stack(
            children: [chartList, if (isZoomed) _zoomResetPill(ref)],
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
    List<CardioWorkout> workouts,
    List<CardioBestEffort> bestEfforts,
    UnitSystem unitSystem,
    DateTimeRange? visibleRange,
  ) {
    final weeklyAggregates = WeeklyActivityAggregator().aggregate(
      days,
      workouts,
    );
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
        PolarizationChart(weeks: _weekZoneDataList(visibleWeeks)),
        const SizedBox(height: AppSpacing.lg),
        const TrainingBalanceStrip(),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Activity Days',
          weeks: _weekDataList(
            visibleWeeks,
            valueFor: (week) => week.activeDays.toDouble(),
            accentColorsFor: (week) =>
                week.cardioWorkoutTypes.mapL(CardioTypePalette.colorFor),
          ),
          barColor: const Color(0xFF64D2FF),
          goalLine: const ChartGoalLine(
            target: 4,
            label: '4d/wk goal',
            color: Color(0xFF64D2FF),
          ),
          formatValue: (value) => '${value.round()}d',
        ),
        const SizedBox(height: AppSpacing.xxl),
        _sectionHeader('Outdoor Running'),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Run Distance',
          weeks: _weekDataList(
            visibleWeeks,
            valueFor: (week) => week.outdoorRunMeters / metersPerUnit,
          ),
          barColor: AppColors.accentPrimary,
          goalLine: ChartGoalLine(
            target: 0.5 * metersPerMile / metersPerUnit,
            label: unitSystem == UnitSystem.imperial
                ? '0.5mi/wk goal'
                : '0.8km/wk goal',
            color: AppColors.accentPrimary,
          ),
          formatValue: (value) => '${value.toStringAsFixed(1)}$distanceUnit',
        ),
        const SizedBox(height: AppSpacing.lg),
        CardioTrendChart(
          title: 'Outdoor Run Trends',
          series: const CardioTrendSeriesFactory().build(
            workouts: workouts,
            bestEfforts: bestEfforts,
            unitSystem: unitSystem,
          ),
          displayStart: visibleRange?.start,
          displayEnd: visibleRange?.end,
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textColor4,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: AppColors.borderDepth1),
          ),
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
        .where(
          (week) =>
              !week.weekStart.isBefore(range.start) &&
              week.weekStart.isBefore(rangeEnd),
        )
        .toList();
  }

  List<WeekData> _weekDataList(
    List<WeekAggregate> aggregates, {
    required double Function(WeekAggregate) valueFor,
    List<Color> Function(WeekAggregate)? accentColorsFor,
  }) {
    return aggregates
        .map(
          (aggregate) => WeekData(
            label: aggregate.label,
            value: valueFor(aggregate),
            weekStart: aggregate.weekStart,
            accentColors: accentColorsFor?.call(aggregate) ?? const [],
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
            zoneTime: aggregate.zoneTime,
            isCurrent: aggregate.isCurrent,
            includeInAverage: !aggregate.beforeData,
          ),
        )
        .toList();
  }
}
