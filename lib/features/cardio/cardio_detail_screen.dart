import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/cardio/workout_polarization_card.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';
import 'package:workouts/widgets/logging_tile_provider.dart';

class const CardioDetailScreen({required final CardioWorkout workout})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routePointsAsync = ref.watch(cardioRoutePointsProvider(workout.id));
    final heartRateSamplesAsync = ref.watch(
      cardioHeartRateSamplesProvider(workout.id),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const EAppHeader(title: 'Workout Detail'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ELayout.spaceLg),
          children: [
              _WorkoutSummaryCard(workout: workout),
              if (workout.activityType.hasRoute) ...[
                const SizedBox(height: ELayout.spaceMd),
                routePointsAsync.when(
                  data: (routePoints) => _RouteCard(routePoints: routePoints),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text(
                    'Unable to load route: $error',
                    style: EText.body.medium.copyWith(color: EColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: ELayout.spaceMd),
              heartRateSamplesAsync.when(
                data: (cardioHeartRateSamples) => Column(
                  children: [
                    _heartRateCard(
                      cardioHeartRateSamples,
                      routePointsAsync.asData?.value ?? [],
                    ),
                    if (cardioHeartRateSamples.isNotEmpty) ...[
                      const SizedBox(height: ELayout.spaceMd),
                      WorkoutPolarizationCard(samples: cardioHeartRateSamples),
                    ],
                  ],
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(
                  'Unable to load heart rate: $error',
                  style: EText.body.medium.copyWith(color: EColors.danger),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _heartRateCard(
    List<CardioHeartRateSample> cardioHeartRateSamples,
    List<CardioRoutePoint> routePoints,
  ) {
    final chartSamples = cardioHeartRateSamples
        .map(
          (cardioHeartRateSample) => HeartRateSample(
            id: cardioHeartRateSample.id,
            sessionId: cardioHeartRateSample.workoutId,
            timestamp: cardioHeartRateSample.timestamp,
            bpm: cardioHeartRateSample.bpm,
            source: 'cardio_import',
          ),
        )
        .toList();
    return CardioMetricsCard(samples: chartSamples, routePoints: routePoints);
  }
}

class const _WorkoutSummaryCard({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workout.activityType.displayName, style: EText.section),
          if (_hasRecordedDistance) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              Format.distance(workout.distanceMeters),
              style: EText.title,
            ),
          ],
          const SizedBox(height: ELayout.spaceXs),
          Text(
            _subtitleText(),
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          ),
        ],
      ),
    );
  }

  bool get _hasRecordedDistance =>
      workout.activityType.hasDistance && workout.distanceMeters > 0;

  String _subtitleText() {
    final duration = Format.duration(workout.durationSeconds);
    if (!_hasRecordedDistance) {
      return duration;
    }
    return '$duration  ·  ${Format.pace(workout.durationSeconds, workout.distanceMeters)}';
  }
}

class const _RouteCard({required final List<CardioRoutePoint> routePoints})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routePoints.length < 2) {
      return _noRouteCard();
    }

    final routeLatLngPoints = routePoints
        .map((routePoint) => LatLng(routePoint.latitude, routePoint.longitude))
        .toList();

    return _routeMapCard(routeLatLngPoints, ref.watch(tileProxyUrlProvider));
  }

  Widget _noRouteCard() => Container(
    padding: const EdgeInsets.all(ELayout.spaceMd),
    decoration: BoxDecoration(
      color: EColors.backgroundLift,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
      border: Border.all(color: EColors.border),
    ),
    child: Text(
      'Route unavailable for this workout.',
      style: EText.body.medium.copyWith(color: EColors.textTertiary),
    ),
  );

  Widget _routeMapCard(List<LatLng> routeLatLngPoints, String tileProxyUrl) =>
      Container(
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          child: SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: routeLatLngPoints,
                  padding: const EdgeInsets.all(24),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: '$tileProxyUrl/tiles/{z}/{x}/{y}.png',
                  tileProvider: LoggingCacheTileProvider(tileProxyUrl),
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeLatLngPoints,
                      strokeWidth: 4,
                      color: EColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
