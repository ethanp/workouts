import 'package:flutter/cupertino.dart';
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

    return calendarAsync.when(
      data: (days) => _buildCharts(days, runsAsync.value ?? [], unitSystem),
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
  ) {
    final weeklyAggregates = _aggregateByWeek(days);
    final distanceUnit = unitSystem == UnitSystem.imperial ? 'mi' : 'km';
    final divisor = unitSystem == UnitSystem.imperial ? metersPerMile : 1000.0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _FourWeekSummary(days: days, unitSystem: unitSystem),
        const SizedBox(height: AppSpacing.lg),
        FitnessMomentumChart(days: days),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Distance',
          weeks: _weekDataList(weeklyAggregates,
              valueFor: (w) => w.totalRunMeters / divisor),
          barColor: AppColors.accentPrimary,
          formatValue: (v) => '${v.toStringAsFixed(1)}$distanceUnit',
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Activity Days',
          weeks: _weekDataList(weeklyAggregates,
              valueFor: (w) => w.activeDays.toDouble()),
          barColor: const Color(0xFF64D2FF),
          formatValue: (v) => '${v.round()}d',
        ),
        const SizedBox(height: AppSpacing.lg),
        WeeklyBarChart(
          title: 'Weekly Zone 2',
          weeks: _weekDataList(weeklyAggregates,
              valueFor: (w) => w.zone2Minutes.toDouble()),
          barColor: const Color(0xFF30D158),
          formatValue: (v) => '${v.round()}m',
        ),
        const SizedBox(height: AppSpacing.lg),
        PaceTrendChart(
          title: '1 Mi Pace',
          points: _pacePoints(runs, unitSystem),
          unitLabel: unitSystem == UnitSystem.imperial ? 'mi' : 'km',
        ),
      ],
    );
  }

  List<WeekData> _weekDataList(
    List<WeekAggregate> aggregates, {
    required double Function(WeekAggregate) valueFor,
  }) {
    return aggregates
        .map((w) => WeekData(
              label: w.label,
              value: valueFor(w),
              isCurrent: w.isCurrent,
              includeInAverage: !w.beforeData,
            ))
        .toList();
  }

  List<PacePoint> _pacePoints(List<FitnessRun> runs, UnitSystem unitSystem) {
    final qualifying = runs
        .where((r) => r.distanceMeters >= metersPerMile && r.durationSeconds > 0)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final divisor = unitSystem == UnitSystem.imperial ? metersPerMile : 1000.0;

    return qualifying
        .map((r) => PacePoint(
              date: r.startedAt,
              paceSecondsPerUnit:
                  r.durationSeconds / (r.distanceMeters / divisor),
            ))
        .toList();
  }

  List<WeekAggregate> _aggregateByWeek(List<ActivityCalendarDay> days) {
    final now = DateTime.now();
    final currentMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final earliestMonday = _earliestActivityMonday(days) ?? currentMonday;

    final weekCount =
        ((currentMonday.difference(earliestMonday).inDays ~/ 7) + 1)
            .clamp(1, 200);

    final byMonday = <DateTime, WeekAggregate>{};
    for (var i = 0; i < weekCount; i++) {
      final monday =
          currentMonday.subtract(Duration(days: 7 * (weekCount - 1 - i)));
      byMonday[monday] = WeekAggregate(
        label: '${monday.month}/${monday.day}',
        isCurrent: i == weekCount - 1,
        beforeData: monday.isBefore(earliestMonday),
      );
    }

    for (final d in days) {
      if (!d.hasActivity) continue;
      final monday = d.date.subtract(Duration(days: d.date.weekday - 1));
      final key = DateTime(monday.year, monday.month, monday.day);
      final agg = byMonday[key];
      if (agg == null) continue;
      agg.totalRunMeters += d.totalRunDistanceMeters;
      agg.zone2Minutes += d.runZone2Minutes;
      agg.activeDays++;
    }

    return byMonday.values.toList();
  }

  DateTime? _earliestActivityMonday(List<ActivityCalendarDay> days) {
    DateTime? earliest;
    for (final d in days) {
      if (!d.hasActivity) continue;
      if (earliest == null || d.date.isBefore(earliest)) earliest = d.date;
    }
    if (earliest == null) return null;
    return DateTime(earliest.year, earliest.month, earliest.day)
        .subtract(Duration(days: earliest.weekday - 1));
  }
}

class WeekAggregate {
  WeekAggregate({
    required this.label,
    this.isCurrent = false,
    this.beforeData = false,
  });

  final String label;
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
    final recentDays =
        days.where((d) => d.date.isAfter(fourWeeksAgo) && d.hasActivity);

    var totalMeters = 0.0;
    var totalRunSeconds = 0;
    var totalSessionMinutes = 0;
    var totalZone2 = 0;
    var activityDayCount = 0;

    for (final d in recentDays) {
      totalMeters += d.totalRunDistanceMeters;
      totalRunSeconds += d.totalRunDurationSeconds;
      totalSessionMinutes += d.totalSessionDurationSeconds ~/ 60;
      totalZone2 += d.runZone2Minutes;
      activityDayCount++;
    }

    final divisor = unitSystem == UnitSystem.imperial ? metersPerMile : 1000.0;
    final distanceUnit = unitSystem == UnitSystem.imperial ? 'mi' : 'km';
    final distance = totalMeters / divisor;
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
                runHours > 0
                    ? '${runHours}h ${runMinutes}m'
                    : '${runMinutes}m',
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
              style:
                  AppTypography.caption.copyWith(color: AppColors.textColor3),
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
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textColor1,
            ),
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
