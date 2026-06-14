import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/exercise_history/exercise_history_provider.dart';
import 'package:workouts/features/active_session/session_detail/exercise_progress_metrics.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/cardio_trend_chart.dart';
import 'package:workouts/widgets/trend_series.dart';

/// Per-exercise card on the session detail screen. The chart of recent
/// sessions is the focal element; this session's point is ringed via
/// [sessionDate]. Cues are intentionally absent — the user lives this
/// session, the chart situates it within their progress.
class ExerciseProgressCard extends ConsumerWidget {
  const ExerciseProgressCard({
    super.key,
    required this.exercise,
    required this.exerciseLogs,
    required this.sessionDate,
  });

  final WorkoutExercise exercise;
  final List<SessionSetLog> exerciseLogs;
  final DateTime sessionDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(exerciseHistoryProvider(exercise.id));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.sm),
          _chartSlot(historyAsync),
          if (exerciseLogs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _setStrip(),
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
        Expanded(
          child: Text(exercise.name, style: AppTypography.subtitle),
        ),
        Text(
          '$completedSets/$targetSets sets',
          style: AppTypography.caption.copyWith(
            color: completedSets >= targetSets
                ? AppColors.success
                : AppColors.textColor3,
          ),
        ),
      ],
    );
  }

  Widget _chartSlot(AsyncValue<List<ExerciseHistoryEntry>> historyAsync) {
    return historyAsync.when(
      data: _chartFromHistory,
      loading: () => const _ChartPlaceholder(),
      error: (_, __) => const _ChartPlaceholder(label: 'Could not load trend'),
    );
  }

  Widget _chartFromHistory(List<ExerciseHistoryEntry> entries) {
    final metrics = ExerciseProgressMetrics(exercise);
    final points = metrics.pointsFromHistory(entries);
    return CardioTrendChart(
      title: 'Progress',
      highlightDate: sessionDate,
      series: [
        TrendSeries(
          label: 'Top set',
          color: AppColors.accentPrimary,
          formatValue: metrics.formatTopSet,
          points: [
            for (final point in points)
              TrendPoint(date: point.date, value: point.topSet),
          ],
        ),
        TrendSeries(
          label: 'Volume',
          color: AppColors.success,
          formatValue: metrics.formatVolume,
          points: [
            for (final point in points)
              TrendPoint(date: point.date, value: point.volume),
          ],
        ),
      ],
    );
  }

  Widget _setStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final log in exerciseLogs)
          SessionSetLogRow(log: log, exercise: exercise),
      ],
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      alignment: Alignment.center,
      child: label == null
          ? const CupertinoActivityIndicator()
          : Text(label!, style: AppTypography.caption),
    );
  }
}
