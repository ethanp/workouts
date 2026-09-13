import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workout_polarization_card.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';

class const CardioHeartRateAndZones({
  required final AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
  required final List<CardioRoutePoint> routePoints,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return heartRateSamplesAsync.when(
      data: (cardioHeartRateSamples) {
        if (cardioHeartRateSamples.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            const SizedBox(height: ELayout.spaceMd),
            CardioMetricsCard(
              samples: [
                for (final sample in cardioHeartRateSamples)
                  HeartRateSample(
                    id: sample.id,
                    sessionId: sample.workoutId,
                    timestamp: sample.timestamp,
                    bpm: sample.bpm,
                    source: 'cardio_import',
                  ),
              ],
              routePoints: routePoints,
            ),
            const SizedBox(height: ELayout.spaceMd),
            WorkoutPolarizationCard(samples: cardioHeartRateSamples),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: ELayout.spaceMd),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: ELayout.spaceMd),
        child: Text(
          'Unable to load heart rate: $error',
          style: EText.body.medium.copyWith(color: EColors.danger),
        ),
      ),
    );
  }
}
