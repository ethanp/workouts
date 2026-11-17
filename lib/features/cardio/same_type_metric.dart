import 'dart:math' as math;

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/distance_bucket.dart';

class const SameTypeMetric({
  required final String id,
  required final String label,
  required final Color color,
  required final double? Function(CardioWorkout workout) valueOf,
  required final String Function(double value) format,
}) {
  static const _plotFloor = 0.08;
  static const _plotCeiling = 0.92;

  static List<SameTypeMetric> forType(CardioType activityType) => [
    SameTypeMetric(
      id: 'duration',
      label: 'Duration',
      color: EColors.accentGlow,
      valueOf: (workout) => workout.durationSeconds / 60,
      format: (minutes) =>
          Duration(seconds: (minutes * 60).round()).formattedHm,
    ),
    SameTypeMetric(
      id: 'heartRate',
      label: 'Avg HR',
      color: EColors.danger,
      valueOf: (workout) => workout.averageHeartRateBpm,
      format: (bpm) => '${bpm.round()} bpm',
    ),
    _work(activityType),
    SameTypeMetric(
      id: 'zone2Plus',
      label: 'Z2–5 time',
      color: EColors.success,
      valueOf: (workout) => workout.zoneTime.total <= 0
          ? null
          : workout.zoneTime.gteZone2Minutes.toDouble(),
      format: (minutes) => '${minutes.round()}m',
    ),
    SameTypeMetric(
      id: 'mets',
      label: 'METs',
      color: EColors.warning,
      valueOf: (workout) => workout.averageMets,
      format: (mets) => mets.toStringAsFixed(1),
    ),
  ];

  static SameTypeMetric _work(CardioType activityType) =>
      switch (activityType.primaryWork) {
        CardioPrimaryWork.flightsAndSteps => SameTypeMetric(
          id: 'flights',
          label: 'Flights',
          color: EColors.pending,
          valueOf: (workout) => workout.flightsClimbed,
          format: (flights) => '${flights.round()}',
        ),
        CardioPrimaryWork.distanceAndPace ||
        CardioPrimaryWork.machineDistanceAndMets => SameTypeMetric(
          id: 'distance',
          label: 'Distance',
          color: EColors.pending,
          valueOf: (workout) => workout.displayDistanceMeters <= 0
              ? null
              : workout.displayDistanceMeters.asMiles,
          format: (miles) => '${miles.toStringAsFixed(2)} mi',
        ),
      };

  String captionFor(CardioWorkout workout) {
    final value = valueOf(workout);
    return value == null ? '—' : format(value);
  }

  List<double> valuesAcross(List<CardioWorkout> workouts) => [
    for (final workout in workouts) ?valueOf(workout),
  ];

  double Function(double value) normalizerAcross(List<CardioWorkout> workouts) {
    final values = valuesAcross(workouts);
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final range = hi - lo;
    return (value) {
      if (range <= 0) return 0.5;
      return _plotFloor + (value - lo) / range * (_plotCeiling - _plotFloor);
    };
  }
}
