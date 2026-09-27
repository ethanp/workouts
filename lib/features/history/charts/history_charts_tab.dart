import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/cardio/cardio_browse_providers.dart';
import 'package:workouts/theme/goal_priority_palette.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/models/distance_bucket.dart';
import 'package:workouts/widgets/metric_trend.dart';
import 'package:workouts/widgets/metric_trend_chart.dart';
import 'package:workouts/widgets/metric_trend_painter.dart';
import 'package:workouts/features/history/charts/history_chart_minimap.dart';
import 'package:workouts/features/history/charts/history_chart_range_scrubber.dart';
import 'package:workouts/features/history/charts/outdoor_run_trends.dart';
import 'package:workouts/features/history/charts/polarization_chart.dart';
import 'package:workouts/features/history/charts/polarization_minute_axis.dart';
import 'package:workouts/features/history/charts/rolling_daily_chart.dart';
import 'package:workouts/features/history/charts/rolling_daily_painter.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/features/history/charts/trailing_seven_day_totals.dart';
import 'package:workouts/features/history/charts/week_zone_data.dart';
import 'package:workouts/features/history/charts/weekly_activity_aggregator.dart';
import 'package:workouts/features/history/charts/weekly_bar_chart.dart';
import 'package:workouts/widgets/zoomable_chart_area.dart';

class const HistoryChartsTab() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final cardioWorkoutsAsync = ref.watch(cardioWorkoutsProvider);
    final bestEffortsAsync = ref.watch(cardioBestEffortsProvider);
    final fullRange = ref.watch(chartDateRangeProvider);
    final zoomRange = ref.watch(chartZoomProvider);
    final visibleRange =
        zoomRange ??
        (fullRange != null
            ? ChartZoomNotifier.defaultVisibleRange(fullRange)
            : null);

    return calendarAsync.when(
      data: (days) {
        final chartList = _chartList(
          context,
          days,
          cardioWorkoutsAsync.value ?? [],
          bestEffortsAsync.value ?? [],
          visibleRange,
          fullRange,
        );
        if (fullRange == null) return chartList;

        final isZoomed = zoomRange != null;
        return ZoomableChartArea(
          fullRange: fullRange,
          child: Stack(
            children: [chartList, if (isZoomed) _zoomResetPill(ref)],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load data: $error',
          style: EText.body.medium.copyWith(color: EColors.danger),
        ),
      ),
    );
  }

  Widget _chartList(
    BuildContext context,
    List<ActivityCalendarDay> days,
    List<CardioWorkout> workouts,
    List<CardioBestEffort> bestEfforts,
    DateTimeRange? visibleRange,
    DateTimeRange? fullRange,
  ) {
    final weeklyAggregates = WeeklyActivityAggregator().aggregate(
      days,
      workouts,
    );
    final visibleWeeks = visibleRange != null
        ? _filterWeeksToRange(weeklyAggregates, visibleRange)
        : weeklyAggregates;
    final now = DateTime.now();
    final List<RollingDailyPoint> rollingZ2LoadPoints =
        const TrailingSevenDayTotals().build(
          days: days,
          endDate: now,
          dailyValue: (day) => day.totalZoneTime.gteZone2 / 60,
        );
    final List<RollingDailyPoint> rollingActiveDaysPoints =
        const TrailingSevenDayTotals().build(
          days: days,
          endDate: now,
          dailyValue: (day) => day.hasActivity ? 1.0 : 0.0,
        );

    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg)
          .withOverlaidTabBar(context),
      children: [
        RollingDailyChart(
          title: 'Z2-5 Rolling Load',
          points: rollingZ2LoadPoints,
          lineColor: HrZonePalette.zone2,
          formatValue: (value) => '${value.round()}m',
          clockMinuteAxis: true,
          summarySuffix: ' / 7d',
          showGoalDailyPace: true,
          emptySummaryLabel: 'No HR load yet',
          goals: const [
            RollingDailyGoal(
              value: 90,
              label: '90m priority 1',
              color: HrZonePalette.zone2,
            ),
            RollingDailyGoal(
              value: 150,
              label: '150m priority 2',
              color: GoalPriorityPalette.priority2,
            ),
          ],
          displayStart: visibleRange?.start,
          displayEnd: visibleRange?.end,
          rangeScrubber: _rollingRangeScrubber(
            fullRange,
            points: rollingZ2LoadPoints,
            lineColor: HrZonePalette.zone2,
          ),
        ),
        const SizedBox(height: ELayout.spaceLg),
        PolarizationChart(
          weeks: _weekZoneDataList(visibleWeeks),
          rangeScrubber: _polarizationRangeScrubber(
            fullRange,
            weeks: _weekZoneDataList(weeklyAggregates),
          ),
        ),
        const SizedBox(height: ELayout.spaceLg),
        RollingDailyChart(
          title: 'Activity (7-day)',
          points: rollingActiveDaysPoints,
          lineColor: const Color(0xFF64D2FF),
          formatValue: (days) {
            final oneDecimal = days.toStringAsFixed(1);
            final label = oneDecimal.endsWith('.0')
                ? oneDecimal.substring(0, oneDecimal.length - 2)
                : oneDecimal;
            return '${label}d';
          },
          summarySuffix: ' / 7d',
          emptySummaryLabel: 'No activity yet',
          goals: const [
            RollingDailyGoal(
              value: 4,
              label: '4d/wk goal',
              color: Color(0xFF64D2FF),
            ),
          ],
          displayStart: visibleRange?.start,
          displayEnd: visibleRange?.end,
          rangeScrubber: _rollingRangeScrubber(
            fullRange,
            points: rollingActiveDaysPoints,
            lineColor: const Color(0xFF64D2FF),
          ),
        ),
        const SizedBox(height: 32),
        _OutdoorRunningCharts(
          weeks: _weekDataList(
            visibleWeeks,
            valueFor: (week) => week.outdoorRunMeters.asMiles,
          ),
          allWeeks: _weekDataList(
            weeklyAggregates,
            valueFor: (week) => week.outdoorRunMeters.asMiles,
          ),
          workouts: workouts,
          bestEfforts: bestEfforts,
          displayStart: visibleRange?.start,
          displayEnd: visibleRange?.end,
          fullRange: fullRange,
        ),
      ],
    );
  }

  Widget? _rollingRangeScrubber(
    DateTimeRange? fullRange, {
    required List<RollingDailyPoint> points,
    required Color lineColor,
  }) {
    if (fullRange == null) return null;
    return Padding(
      padding: const EdgeInsets.only(
        left: RollingDailyPainter.leftPadding,
        right: RollingDailyPainter.rightPadding,
      ),
      child: HistoryChartRangeScrubber(
        fullRange: fullRange,
        windowColor: lineColor,
        plot: RollingDailyMinimapPainter(
          points: points,
          fullStart: fullRange.start,
          fullEnd: fullRange.end,
          lineColor: lineColor,
        ),
      ),
    );
  }

  Widget? _polarizationRangeScrubber(
    DateTimeRange? fullRange, {
    required List<WeekZoneData> weeks,
  }) {
    if (fullRange == null) return null;
    return Padding(
      padding: const EdgeInsets.only(left: PolarizationMinuteAxis.width),
      child: HistoryChartRangeScrubber(
        fullRange: fullRange,
        windowColor: EColors.accent,
        plot: StackedZoneWeekMinimapPainter(
          weeks: weeks,
          fullStart: fullRange.start,
          fullEnd: fullRange.end,
        ),
      ),
    );
  }

  Widget _zoomResetPill(WidgetRef ref) {
    return Positioned(
      top: ELayout.spaceMd,
      right: ELayout.spaceMd,
      child: GestureDetector(
        onTap: () => ref.read(chartZoomProvider.notifier).reset(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceSm,
            vertical: ELayout.spaceXs,
          ),
          decoration: BoxDecoration(
            color: EColors.backgroundLift.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(ELayout.radiusSm),
            border: Border.all(color: EColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.compare_arrows, size: 12, color: EColors.accent),
              const SizedBox(width: 4),
              Text(
                'Reset zoom',
                style: EText.caption.copyWith(
                  color: EColors.accent,
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
    final rangeEnd = range.end.shiftedByDays(7);
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
            zoneTime: aggregate.zoneTime,
            isCurrent: aggregate.isCurrent,
            includeInAverage: !aggregate.beforeData,
          ),
        )
        .toList();
  }
}

class const _OutdoorRunningCharts({
  required final List<WeekData> weeks,
  required final List<WeekData> allWeeks,
  required final List<CardioWorkout> workouts,
  required final List<CardioBestEffort> bestEfforts,
  final DateTime? displayStart,
  final DateTime? displayEnd,
  final DateTimeRange? fullRange,
}) extends StatefulWidget {
  @override
  State<_OutdoorRunningCharts> createState() => _OutdoorRunningChartsState();
}

class _OutdoorRunningChartsState() extends State<_OutdoorRunningCharts> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_sectionHeader(), if (_expanded) ..._expandedCharts()],
    );
  }

  List<Widget> _expandedCharts() {
    final List<MetricTrend> trends = _outdoorRunTrends();
    return [
      const SizedBox(height: ELayout.spaceLg),
      WeeklyBarChart(
        title: 'Weekly Run Distance',
        weeks: widget.weeks,
        barColor: EColors.accent,
        goalLine: const ChartGoalLine(
          target: 0.5,
          label: '0.5mi/wk goal',
          color: EColors.accent,
        ),
        formatValue: (value) => '${value.toStringAsFixed(1)}mi',
        rangeScrubber: _weeklyDistanceScrubber(),
      ),
      const SizedBox(height: ELayout.spaceLg),
      MetricTrendChart(
        title: 'Outdoor Run Trends',
        trends: trends,
        displayStart: widget.displayStart,
        displayEnd: widget.displayEnd,
        rangeScrubber: _trendScrubber(trends),
      ),
    ];
  }

  List<MetricTrend> _outdoorRunTrends() {
    return const OutdoorRunTrends().build(
      workouts: widget.workouts,
      bestEfforts: widget.bestEfforts,
    );
  }

  Widget? _weeklyDistanceScrubber() {
    final DateTimeRange? fullRange = widget.fullRange;
    if (fullRange == null) return null;
    return HistoryChartRangeScrubber(
      fullRange: fullRange,
      windowColor: EColors.accent,
      plot: WeeklyValueMinimapPainter(
        weeks: widget.allWeeks,
        fullStart: fullRange.start,
        fullEnd: fullRange.end,
        barColor: EColors.accent,
      ),
    );
  }

  Widget? _trendScrubber(List<MetricTrend> trends) {
    final DateTimeRange? fullRange = widget.fullRange;
    if (fullRange == null) return null;
    return Padding(
      padding: const EdgeInsets.only(
        left: MetricTrendPainter.plotLeftPadding,
        right: MetricTrendPainter.plotRightPadding,
      ),
      child: HistoryChartRangeScrubber(
        fullRange: fullRange,
        windowColor: EColors.accent,
        plot: MetricTrendMinimapPainter(
          trends: trends,
          fullStart: fullRange.start,
          fullEnd: fullRange.end,
        ),
      ),
    );
  }

  Widget _sectionHeader() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            'OUTDOOR RUNNING',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: EColors.textMuted,
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            size: 11,
            color: EColors.textMuted,
          ),
          const SizedBox(width: ELayout.spaceMd),
          const Expanded(
            child: SizedBox(
              height: 0.5,
              child: ColoredBox(color: EColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
