import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/trend_series.dart';

class CardioTrendSeriesFactory {
  const CardioTrendSeriesFactory();

  List<TrendSeries> build({
    required List<CardioWorkout> workouts,
    required List<CardioBestEffort> bestEfforts,
  }) {
    final chronologicalWorkouts = _chronologicalWorkouts(workouts);
    return [
      ..._bestEffortSeries(bestEfforts),
      _distanceSeries(chronologicalWorkouts),
      _avgHrSeries(chronologicalWorkouts),
      _maxHrSeries(chronologicalWorkouts),
      _caloriesSeries(chronologicalWorkouts),
      _durationSeries(chronologicalWorkouts),
    ];
  }

  List<CardioWorkout> _chronologicalWorkouts(List<CardioWorkout> workouts) {
    return workouts
        .whereL(
          (workout) =>
              workout.activityType == CardioType.outdoorRun &&
              workout.durationSeconds > 0,
        )
        .sortedOn((workout) => workout.startedAt);
  }

  static const _bucketColors = <DistanceBucket, Color>{
    DistanceBucket.fourHundredMeters: Color(0xFFFF9F0A),
    DistanceBucket.halfMile: Color(0xFFFF6482),
    DistanceBucket.oneMile: AppColors.accentPrimary,
    DistanceBucket.fiveK: Color(0xFF30D158),
    DistanceBucket.fiveMiles: Color(0xFF64D2FF),
  };

  List<TrendSeries> _bestEffortSeries(List<CardioBestEffort> bestEfforts) {
    final byBucket = <DistanceBucket, List<CardioBestEffort>>{};
    for (final effort in bestEfforts) {
      (byBucket[effort.bucket] ??= []).add(effort);
    }

    return [
      for (final bucket in DistanceBucket.values)
        if (byBucket[bucket] != null && byBucket[bucket]!.length >= 2)
          TrendSeries(
            label: bucket.label,
            color: _bucketColors[bucket] ?? AppColors.accentPrimary,
            invertY: true,
            points: byBucket[bucket]!
                .where((bestEffort) => bestEffort.workoutStartedAt != null)
                .map(
                  (bestEffort) => TrendPoint(
                    date: bestEffort.workoutStartedAt!,
                    value: bestEffort.paceSecondsPerUnit(metersPerMile),
                  ),
                )
                .toList(),
            formatValue: (paceValue) => Format.paceValue(paceValue),
          ),
    ];
  }

  TrendSeries _distanceSeries(List<CardioWorkout> workouts) {
    return TrendSeries(
      label: 'Distance',
      color: const Color(0xFF30D158),
      points: workouts
          .map(
            (workout) => TrendPoint(
              date: workout.startedAt,
              value: workout.distanceMeters / metersPerMile,
            ),
          )
          .toList(),
      formatValue: (distanceValue) => '${distanceValue.toStringAsFixed(1)}mi',
    );
  }

  TrendSeries _avgHrSeries(List<CardioWorkout> workouts) {
    return TrendSeries(
      label: 'Avg HR',
      color: const Color(0xFFFF453A),
      points: workouts
          .where((workout) => workout.averageHeartRateBpm != null)
          .map(
            (workout) => TrendPoint(
              date: workout.startedAt,
              value: workout.averageHeartRateBpm!,
            ),
          )
          .toList(),
      formatValue: (heartRateValue) => '${heartRateValue.round()} bpm',
    );
  }

  TrendSeries _maxHrSeries(List<CardioWorkout> workouts) {
    return TrendSeries(
      label: 'Max HR',
      color: const Color(0xFFFF6961),
      points: workouts
          .where((workout) => workout.maxHeartRateBpm != null)
          .map(
            (workout) => TrendPoint(
              date: workout.startedAt,
              value: workout.maxHeartRateBpm!,
            ),
          )
          .toList(),
      formatValue: (heartRateValue) => '${heartRateValue.round()} bpm',
    );
  }

  TrendSeries _caloriesSeries(List<CardioWorkout> workouts) {
    return TrendSeries(
      label: 'Calories',
      color: const Color(0xFFFFD60A),
      points: workouts
          .where((workout) => workout.energyKcal != null)
          .map(
            (workout) =>
                TrendPoint(date: workout.startedAt, value: workout.energyKcal!),
          )
          .toList(),
      formatValue: (caloriesValue) => '${caloriesValue.round()} kcal',
    );
  }

  TrendSeries _durationSeries(List<CardioWorkout> workouts) {
    return TrendSeries(
      label: 'Duration',
      color: const Color(0xFF64D2FF),
      points: workouts
          .map(
            (workout) => TrendPoint(
              date: workout.startedAt,
              value: workout.durationSeconds.toDouble(),
            ),
          )
          .toList(),
      formatValue: (durationValue) =>
          Format.durationShort(durationValue.round()),
    );
  }
}
