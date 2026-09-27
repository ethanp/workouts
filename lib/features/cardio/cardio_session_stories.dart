import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';

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
        CardioHeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: const [],
        ),
        CardioSessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
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
        CardioHeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: const [],
        ),
        CardioSessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }
}
