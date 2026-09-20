import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/models/fitness_signal_confidence.dart';

import 'cardio_detail_card.dart';
import 'cardio_heart_rate_and_zones.dart';
import 'cardio_route_card.dart';
import 'cardio_session_structure_card.dart';

class const OutdoorWalkStory({
  required final CardioWorkout workout,
  required final AsyncValue<List<CardioRoutePoint>> routePointsAsync,
  required final AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        routePointsAsync.when(
          data: (routePoints) => CardioRouteCard(routePoints: routePoints),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            'Unable to load route: $error',
            style: EText.body.medium.copyWith(color: EColors.danger),
          ),
        ),
        CardioElevationCaption(workout: workout, indoorIncline: false),
        CardioHeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: routePointsAsync.asData?.value ?? const [],
        ),
        CardioSessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }
}

class const MachineCardioStory({
  required final CardioWorkout workout,
  required final AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MachineCardioNotes(workout: workout),
        CardioHeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: const [],
        ),
        CardioSessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }
}

class const MachineCardioNotes({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notes = <String>[];
    if (workout.hasCyclingMachineStats) {
      _addCyclingNotes(notes);
    } else if (workout.activityType.primaryWork ==
        CardioPrimaryWork.machineDistanceAndMets) {
      _addDifferingMachineDuration(notes);
    } else {
      _addIndoorWalkRunNotes(notes);
    }
    _addEarnedFitnessNotes(notes);
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceMd),
      child: CardioDetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
                child: Text(
                  note,
                  style: EText.caption.copyWith(color: EColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addCyclingNotes(List<String> notes) {
    _addDifferingMachineDuration(notes);
    if (workout.cyclingPowerCaption case final power?) notes.add(power);
    if (workout.cyclingCadenceCaption case final cadence?) notes.add(cadence);
    if (workout.cyclingSpeedCaption case final speed?) notes.add(speed);
  }

  void _addDifferingMachineDuration(List<String> notes) {
    final machineDurationSeconds = workout.fitnessMachineDurationSeconds;
    if (machineDurationSeconds == null) return;
    if ((machineDurationSeconds - workout.durationSeconds).abs() < 5) return;
    notes.add(
      'Machine duration ${Duration(seconds: machineDurationSeconds.round()).formattedHms}',
    );
  }

  void _addIndoorWalkRunNotes(List<String> notes) {
    final stepCount = workout.stepCount;
    if (stepCount != null && stepCount > 0) {
      notes.add(workout.stepsCaption!);
    }
    final elevationAscendedMeters = workout.elevationAscendedMeters;
    if (elevationAscendedMeters != null && elevationAscendedMeters > 0) {
      notes.add('${elevationAscendedMeters.round()} m gain / incline');
    }
  }

  void _addEarnedFitnessNotes(List<String> notes) {
    if (workout.fitnessConfidence == FitnessSignalConfidence.insufficient) {
      return;
    }
    final cardiacDriftPercent = workout.cardiacDriftPercent;
    if (cardiacDriftPercent != null) {
      notes.add('HR drift ${cardiacDriftPercent.toStringAsFixed(1)}%');
    }
    final metersPerHeartbeat = workout.metersPerHeartbeat;
    if (metersPerHeartbeat != null) {
      notes.add('${metersPerHeartbeat.toStringAsFixed(2)} m / beat');
    }
  }
}

class const StairClimbStory({
  required final CardioWorkout workout,
  required final AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StairClimbNotes(workout: workout),
        CardioHeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: const [],
        ),
        CardioSessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }
}

class const StairClimbNotes({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notes = <String>[];
    final flightsClimbed = workout.flightsClimbed;
    if (flightsClimbed != null && flightsClimbed > 0) {
      notes.add(workout.flightsCaption!);
    }
    final stepCount = workout.stepCount;
    if (stepCount != null && stepCount > 0) {
      notes.add(workout.stepsCaption!);
    }
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceMd),
      child: CardioDetailCard(
        child: Text(
          notes.join('  ·  '),
          style: EText.body.medium.copyWith(color: EColors.textSecondary),
        ),
      ),
    );
  }
}
