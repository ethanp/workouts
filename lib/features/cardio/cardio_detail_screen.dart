import 'package:flutter/cupertino.dart';
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
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';
import 'package:workouts/widgets/logging_tile_provider.dart';

class CardioDetailScreen extends ConsumerWidget {
  const CardioDetailScreen({super.key, required this.workout});

  final CardioWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routePointsAsync = ref.watch(cardioRoutePointsProvider(workout.id));
    final heartRateSamplesAsync = ref.watch(
      cardioHeartRateSamplesProvider(workout.id),
    );

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Workout Detail'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _WorkoutSummaryCard(workout: workout),
            if (workout.activityType.hasRoute) ...[
              const SizedBox(height: AppSpacing.md),
              routePointsAsync.when(
                data: (routePoints) => _RouteCard(routePoints: routePoints),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, _) => Text(
                  'Unable to load route: $error',
                  style: AppTypography.body.copyWith(color: AppColors.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            heartRateSamplesAsync.when(
              data: (cardioHeartRateSamples) => Column(
                children: [
                  _heartRateCard(
                    cardioHeartRateSamples,
                    routePointsAsync.asData?.value ?? [],
                  ),
                  if (cardioHeartRateSamples.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    WorkoutPolarizationCard(samples: cardioHeartRateSamples),
                  ],
                ],
              ),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, _) => Text(
                'Unable to load heart rate: $error',
                style: AppTypography.body.copyWith(color: AppColors.error),
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

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({required this.workout});

  final CardioWorkout workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workout.activityType.displayName, style: AppTypography.subtitle),
          if (_hasRecordedDistance) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              Format.distance(workout.distanceMeters),
              style: AppTypography.title,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            _subtitleText(),
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
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

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.routePoints});

  final List<CardioRoutePoint> routePoints;

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
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDepth1),
    ),
    child: Text(
      'Route unavailable for this workout.',
      style: AppTypography.body.copyWith(color: AppColors.textColor3),
    ),
  );

  Widget _routeMapCard(List<LatLng> routeLatLngPoints, String tileProxyUrl) =>
      Container(
    decoration: BoxDecoration(
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDepth1),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
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
                  color: AppColors.accentPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
