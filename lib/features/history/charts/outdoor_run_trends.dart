import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/metric_trend.dart';

class const OutdoorRunTrends() {
  List<MetricTrend> build({
    required List<CardioWorkout> workouts,
    required List<CardioBestEffort> bestEfforts,
  }) {
    final chronologicalWorkouts = _outdoorRunsInStartOrder(workouts);
    return [
      ..._bestEffortPaces(bestEfforts),
      _runDistances(chronologicalWorkouts),
      _averageHeartRates(chronologicalWorkouts),
      _maxHeartRates(chronologicalWorkouts),
      _calories(chronologicalWorkouts),
      _durations(chronologicalWorkouts),
    ];
  }

  List<CardioWorkout> _outdoorRunsInStartOrder(List<CardioWorkout> workouts) {
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
    DistanceBucket.oneMile: EColors.accent,
    DistanceBucket.fiveK: Color(0xFF30D158),
    DistanceBucket.fiveMiles: Color(0xFF64D2FF),
  };

  List<MetricTrend> _bestEffortPaces(List<CardioBestEffort> bestEfforts) {
    final byBucket = <DistanceBucket, List<CardioBestEffort>>{};
    for (final effort in bestEfforts) {
      (byBucket[effort.bucket] ??= []).add(effort);
    }

    return [
      for (final bucket in DistanceBucket.values)
        if (byBucket[bucket] != null && byBucket[bucket]!.length >= 2)
          MetricTrend(
            label: bucket.label,
            color: _bucketColors[bucket] ?? EColors.accent,
            lowerIsBetter: true,
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

  MetricTrend _runDistances(List<CardioWorkout> workouts) {
    return MetricTrend(
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

  MetricTrend _averageHeartRates(List<CardioWorkout> workouts) {
    return MetricTrend(
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

  MetricTrend _maxHeartRates(List<CardioWorkout> workouts) {
    return MetricTrend(
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

  MetricTrend _calories(List<CardioWorkout> workouts) {
    return MetricTrend(
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

  MetricTrend _durations(List<CardioWorkout> workouts) {
    return MetricTrend(
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
