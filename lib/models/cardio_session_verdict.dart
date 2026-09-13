import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/utils/run_formatting.dart';

enum CardioAerobicJob({required this.label}) {
  easyAerobic(label: 'Easy aerobic'),
  steadyAerobic(label: 'Steady aerobic'),
  hardAerobic(label: 'Hard aerobic'),
  unknown(label: 'Cardio');

  final String label;
}

class const CardioPrimaryWorkMetric({
  required final String headline,
  final String? supporting,
});

class const CardioSessionVerdict({
  required final CardioAerobicJob aerobicJob,
  required final CardioPrimaryWorkMetric primaryWork,
  required final int dominantZoneIndex,
}) {
  factory fromWorkout(CardioWorkout workout) {
    return CardioSessionVerdict(
      aerobicJob: _aerobicJob(workout.zoneTime),
      primaryWork: _primaryWork(workout),
      dominantZoneIndex: workout.zoneTime.dominantZoneIndex,
    );
  }

  static CardioAerobicJob _aerobicJob(HrZoneTime zoneTime) {
    if (zoneTime.total <= 0) return CardioAerobicJob.unknown;
    final hardShare = zoneTime.hardAerobicSeconds / zoneTime.total;
    final easyShare = zoneTime.easyAerobicSeconds / zoneTime.total;
    if (hardShare >= 0.20 || zoneTime.dominantZoneIndex >= 3) {
      return CardioAerobicJob.hardAerobic;
    }
    if (easyShare >= 0.60 || zoneTime.dominantZoneIndex <= 1) {
      return CardioAerobicJob.easyAerobic;
    }
    return CardioAerobicJob.steadyAerobic;
  }

  static CardioPrimaryWorkMetric _primaryWork(CardioWorkout workout) {
    return switch (workout.activityType.primaryWork) {
      CardioPrimaryWork.distanceAndPace => _distanceAndPace(workout),
      CardioPrimaryWork.machineDistanceAndMets => _machineDistanceAndMets(
        workout,
      ),
      CardioPrimaryWork.flightsAndSteps => _flightsAndSteps(workout),
    };
  }

  static CardioPrimaryWorkMetric _distanceAndPace(CardioWorkout workout) {
    if (workout.displayDistanceMeters <= 0) {
      return const CardioPrimaryWorkMetric(headline: '');
    }
    return CardioPrimaryWorkMetric(
      headline: Format.distance(workout.displayDistanceMeters),
      supporting: Format.pace(
        workout.durationSeconds,
        workout.displayDistanceMeters,
      ),
    );
  }

  static CardioPrimaryWorkMetric _machineDistanceAndMets(CardioWorkout workout) {
    final displayDistanceMeters = workout.displayDistanceMeters;
    final averageMets = workout.averageMets;
    if (displayDistanceMeters <= 0) {
      if (averageMets == null) return const CardioPrimaryWorkMetric(headline: '');
      return CardioPrimaryWorkMetric(headline: Format.mets(averageMets));
    }
    return CardioPrimaryWorkMetric(
      headline: Format.distance(displayDistanceMeters),
      supporting: averageMets == null ? null : Format.mets(averageMets),
    );
  }

  static CardioPrimaryWorkMetric _flightsAndSteps(CardioWorkout workout) {
    final flightsClimbed = workout.flightsClimbed;
    final stepCount = workout.stepCount;
    if (flightsClimbed == null || flightsClimbed <= 0) {
      if (stepCount == null || stepCount <= 0) {
        return const CardioPrimaryWorkMetric(headline: '');
      }
      return CardioPrimaryWorkMetric(headline: Format.steps(stepCount));
    }
    return CardioPrimaryWorkMetric(
      headline: Format.flights(flightsClimbed),
      supporting: stepCount == null || stepCount <= 0
          ? null
          : Format.steps(stepCount),
    );
  }
}
