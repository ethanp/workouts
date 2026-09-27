import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/cardio_session_verdict.dart';
import 'package:workouts/models/distance_bucket.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/fitness_signal_confidence.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

import 'cardio_detail_card.dart';

class const SessionVerdictCard({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final verdict = CardioSessionVerdict.fromWorkout(workout);
    return CardioDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(verdict.aerobicJob.label, style: EText.title),
              ),
              Text(
                workout.startedAt.fullDate,
                style: EText.caption.copyWith(color: EColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: ELayout.spaceMd),
          Wrap(
            spacing: ELayout.spaceLg,
            runSpacing: ELayout.spaceMd,
            children: [
              for (final stat in _stats(verdict)) _LabeledStat(stat: stat),
            ],
          ),
          const SizedBox(height: ELayout.spaceMd),
          Text(
            workout.shortProvenanceCaption,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
      ),
    );
  }

  List<_SessionStat> _stats(CardioSessionVerdict verdict) {
    final stats = <_SessionStat>[
      _SessionStat(value: workout.duration.formattedHms, label: 'Duration'),
    ];
    _addDistance(stats);
    _addPace(stats);
    _addMets(stats);
    _addCycling(stats);
    _addFlights(stats);
    _addSteps(stats);
    _addElevation(stats);
    _addDifferingMachineDuration(stats);
    _addEarnedFitness(stats);
    _addHeartRate(stats);
    _addZone(stats, verdict);
    return stats;
  }

  void _addDistance(List<_SessionStat> stats) {
    if (workout.displayDistanceMeters <= 0) return;
    stats.add(
      _SessionStat(
        value: workout.displayDistanceMeters.milesCaption,
        label: 'Distance',
      ),
    );
  }

  void _addPace(List<_SessionStat> stats) {
    if (workout.activityType.primaryWork != CardioPrimaryWork.distanceAndPace) {
      return;
    }
    if (workout.displayDistanceMeters <= 0) return;
    stats.add(
      _SessionStat(
        value: workout.duration.pacePerMile(workout.displayDistanceMeters),
        label: 'Pace',
      ),
    );
  }

  void _addMets(List<_SessionStat> stats) {
    final averageMets = workout.averageMets;
    if (averageMets == null) return;
    stats.add(
      _SessionStat(value: averageMets.toStringAsFixed(1), label: 'METs'),
    );
  }

  void _addCycling(List<_SessionStat> stats) {
    if (!workout.hasCyclingMachineStats) return;
    if (workout.cyclingPowerCaption case final power?) {
      stats.add(_SessionStat(value: power, label: 'Power'));
    }
    if (workout.cyclingCadenceCaption case final cadence?) {
      stats.add(_SessionStat(value: cadence, label: 'Cadence'));
    }
    if (workout.cyclingSpeedCaption case final speed?) {
      stats.add(_SessionStat(value: speed, label: 'Speed'));
    }
  }

  void _addFlights(List<_SessionStat> stats) {
    final flightsClimbed = workout.flightsClimbed;
    if (flightsClimbed == null || flightsClimbed <= 0) return;
    stats.add(
      _SessionStat(value: '${flightsClimbed.round()}', label: 'Flights'),
    );
  }

  void _addSteps(List<_SessionStat> stats) {
    if (workout.activityType.primaryWork ==
        CardioPrimaryWork.machineDistanceAndMets) {
      return;
    }
    final stepCount = workout.stepCount;
    if (stepCount == null || stepCount <= 0) return;
    stats.add(_SessionStat(value: '${stepCount.round()}', label: 'Steps'));
  }

  void _addElevation(List<_SessionStat> stats) {
    if (workout.activityType.primaryWork == CardioPrimaryWork.flightsAndSteps) {
      return;
    }
    final elevationAscendedMeters = workout.elevationAscendedMeters;
    if (elevationAscendedMeters == null || elevationAscendedMeters <= 0) {
      return;
    }
    stats.add(
      _SessionStat(
        value: '${elevationAscendedMeters.round()} m',
        label: 'Elevation',
      ),
    );
  }

  void _addDifferingMachineDuration(List<_SessionStat> stats) {
    if (workout.activityType.primaryWork !=
            CardioPrimaryWork.machineDistanceAndMets &&
        !workout.hasCyclingMachineStats) {
      return;
    }
    final machineDurationSeconds = workout.fitnessMachineDurationSeconds;
    if (machineDurationSeconds == null) return;
    if ((machineDurationSeconds - workout.durationSeconds).abs() < 5) return;
    stats.add(
      _SessionStat(
        value: Duration(seconds: machineDurationSeconds.round()).formattedHms,
        label: 'Machine',
      ),
    );
  }

  void _addEarnedFitness(List<_SessionStat> stats) {
    if (workout.fitnessConfidence == FitnessSignalConfidence.insufficient) {
      return;
    }
    final cardiacDriftPercent = workout.cardiacDriftPercent;
    if (cardiacDriftPercent != null) {
      stats.add(
        _SessionStat(
          value: '${cardiacDriftPercent.toStringAsFixed(1)}%',
          label: 'HR drift',
        ),
      );
    }
    final metersPerHeartbeat = workout.metersPerHeartbeat;
    if (metersPerHeartbeat != null) {
      stats.add(
        _SessionStat(
          value: metersPerHeartbeat.toStringAsFixed(2),
          label: 'm / beat',
        ),
      );
    }
  }

  void _addHeartRate(List<_SessionStat> stats) {
    final averageHeartRateBpm = workout.averageHeartRateBpm;
    if (averageHeartRateBpm == null) return;
    stats.add(
      _SessionStat(
        value: '${averageHeartRateBpm.round()} bpm',
        label: 'Heart rate',
      ),
    );
  }

  void _addZone(List<_SessionStat> stats, CardioSessionVerdict verdict) {
    if (workout.zoneTime.total <= 0) return;
    stats.add(
      _SessionStat(
        value: HrZonePalette.zoneShortNames[verdict.dominantZoneIndex],
        label: 'Zone',
        valueColor: HrZonePalette.zoneColors[verdict.dominantZoneIndex],
      ),
    );
  }
}

class const _SessionStat({
  required final String value,
  required final String label,
  final Color? valueColor,
});

class const _LabeledStat({required final _SessionStat stat})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          stat.value,
          textAlign: TextAlign.center,
          style: EText.body.large.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: stat.valueColor ?? EColors.textPrimary,
          ),
        ),
        Text(
          stat.label,
          textAlign: TextAlign.center,
          style: EText.label.small.copyWith(
            letterSpacing: -0.4,
            height: 1.15,
            color: EColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
