import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/exercise_history/exercise_history_provider.dart';
import 'package:workouts/features/active_session/session_detail/exercise_progress_metrics.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/widgets/metric_trend.dart';
import 'package:workouts/widgets/metric_trend_chart.dart';

/// Per-exercise card on the session detail screen. The chart of recent
/// sessions is the focal element; this session's point is ringed via
/// [sessionDate]. Cues are intentionally absent — the user lives this
/// session, the chart situates it within their progress.
class const ExerciseProgressCard({
  required final WorkoutExercise exercise,
  required final List<SessionSetLog> exerciseLogs,
  required final DateTime sessionDate,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(exerciseHistoryProvider(exercise.id));
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: ELayout.spaceSm),
          _progressChart(historyAsync),
          if (exerciseLogs.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceSm),
            _loggedSets(),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    final completedSets = exerciseLogs.length;
    final targetSets = exercise.effectiveTargetSets;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(exercise.name, style: EText.section)),
        Text(
          '$completedSets/$targetSets sets',
          style: EText.caption.copyWith(
            color: completedSets >= targetSets
                ? EColors.success
                : EColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _progressChart(AsyncValue<List<ExerciseHistoryEntry>> historyAsync) {
    return historyAsync.when(
      data: _chartFromHistory,
      loading: () => const _ChartPlaceholder(),
      error: (_, _) => const _ChartPlaceholder(label: 'Could not load trend'),
    );
  }

  Widget _chartFromHistory(List<ExerciseHistoryEntry> entries) {
    final metrics = ExerciseProgressMetrics(exercise);
    final points = metrics.pointsFromHistory(entries);
    return MetricTrendChart(
      title: 'Progress',
      highlightDate: sessionDate,
      trends: [
        MetricTrend(
          label: 'Top set',
          color: EColors.accent,
          formatValue: metrics.formatTopSet,
          points: [
            for (final point in points)
              TrendPoint(date: point.date, value: point.topSet),
          ],
        ),
        MetricTrend(
          label: 'Volume',
          color: EColors.success,
          formatValue: metrics.formatVolume,
          points: [
            for (final point in points)
              TrendPoint(date: point.date, value: point.volume),
          ],
        ),
      ],
    );
  }

  Widget _loggedSets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final log in exerciseLogs)
          SessionSetLogRow(log: log, exercise: exercise),
      ],
    );
  }
}

class const _ChartPlaceholder({final String? label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      alignment: Alignment.center,
      child: label == null
          ? const CircularProgressIndicator()
          : Text(label!, style: EText.caption),
    );
  }
}
