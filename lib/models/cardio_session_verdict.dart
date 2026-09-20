import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/distance_bucket.dart';
import 'package:workouts/models/hr_zone_time.dart';

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
      headline: workout.displayDistanceMeters.milesCaption,
      supporting: workout.duration.pacePerMile(workout.displayDistanceMeters),
    );
  }

  static CardioPrimaryWorkMetric _machineDistanceAndMets(CardioWorkout workout) {
    final displayDistanceMeters = workout.displayDistanceMeters;
    if (displayDistanceMeters <= 0) {
      final metsCaption = workout.metsCaption;
      if (metsCaption == null) {
        return const CardioPrimaryWorkMetric(headline: '');
      }
      return CardioPrimaryWorkMetric(headline: metsCaption);
    }
    return CardioPrimaryWorkMetric(
      headline: displayDistanceMeters.milesCaption,
      supporting: _machineSupporting(workout),
    );
  }

  static String? _machineSupporting(CardioWorkout workout) {
    final parts = [
      if (workout.cyclingPowerCaption != null) workout.cyclingPowerCaption!,
      if (workout.cyclingCadenceCaption != null) workout.cyclingCadenceCaption!,
      if (workout.metsCaption != null) workout.metsCaption!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  static CardioPrimaryWorkMetric _flightsAndSteps(CardioWorkout workout) {
    final flightsClimbed = workout.flightsClimbed;
    final stepCount = workout.stepCount;
    if (flightsClimbed == null || flightsClimbed <= 0) {
      if (stepCount == null || stepCount <= 0) {
        return const CardioPrimaryWorkMetric(headline: '');
      }
      return CardioPrimaryWorkMetric(headline: workout.stepsCaption!);
    }
    return CardioPrimaryWorkMetric(
      headline: workout.flightsCaption!,
      supporting: stepCount == null || stepCount <= 0
          ? null
          : workout.stepsCaption,
    );
  }
}
