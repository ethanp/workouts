import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_browse_providers.dart';
import 'cardio_session_stories.dart';
import 'same_type_comparison_card.dart';
import 'session_verdict_card.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';

class const CardioDetailScreen({required final CardioWorkout workout})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestWorkout = _latestWorkout(ref);
    final routePointsAsync = ref.watch(
      cardioRoutePointsProvider(latestWorkout.id),
    );
    final heartRateSamplesAsync = ref.watch(
      cardioHeartRateSamplesProvider(latestWorkout.id),
    );
    final workoutEventsAsync = ref.watch(
      cardioWorkoutEventsProvider(latestWorkout.id),
    );
    final comparison = SameTypeWorkoutComparison.fromCatalog(
      thisWorkout: latestWorkout,
      catalog: ref.watch(cardioWorkoutsProvider).value ?? const [],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(title: latestWorkout.activityType.displayName),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(
            ELayout.spaceLg,
          ).withOverlaidTabBar(context),
          children: [
            SessionVerdictCard(workout: latestWorkout),
            if (comparison.hasPeers) ...[
              const SizedBox(height: ELayout.spaceMd),
              SameTypeComparisonCard(comparison: comparison),
            ],
            const SizedBox(height: ELayout.spaceMd),
            _sessionStory(
              latestWorkout,
              routePointsAsync,
              heartRateSamplesAsync,
              workoutEventsAsync,
            ),
          ],
        ),
      ),
    );
  }

  CardioWorkout _latestWorkout(WidgetRef ref) {
    final workouts = ref.watch(cardioWorkoutsProvider).value;
    if (workouts == null) return workout;
    for (final catalogWorkout in workouts) {
      if (catalogWorkout.id == workout.id) return catalogWorkout;
    }
    return workout;
  }

  Widget _sessionStory(
    CardioWorkout latestWorkout,
    AsyncValue<List<CardioRoutePoint>> routePointsAsync,
    AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
    AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
  ) {
    if (latestWorkout.activityType == CardioType.stairClimbing) {
      return StairClimbStory(
        workout: latestWorkout,
        heartRateSamplesAsync: heartRateSamplesAsync,
        workoutEventsAsync: workoutEventsAsync,
      );
    }
    if (latestWorkout.activityType.hasRoute) {
      return OutdoorWalkStory(
        workout: latestWorkout,
        routePointsAsync: routePointsAsync,
        heartRateSamplesAsync: heartRateSamplesAsync,
        workoutEventsAsync: workoutEventsAsync,
      );
    }
    return MachineCardioStory(
      workout: latestWorkout,
      heartRateSamplesAsync: heartRateSamplesAsync,
      workoutEventsAsync: workoutEventsAsync,
    );
  }
}
