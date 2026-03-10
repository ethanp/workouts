import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/providers/cardio_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
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
    final heartRateSamplesAsync = ref.watch(cardioHeartRateSamplesProvider(workout.id));
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Workout Detail')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _WorkoutSummaryCard(workout: workout, unitSystem: unitSystem),
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
            const SizedBox(height: AppSpacing.md),
            heartRateSamplesAsync.when(
              data: (cardioHeartRateSamples) {
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
                return CardioMetricsCard(
                  samples: chartSamples,
                  routePoints: routePointsAsync.asData?.value ?? [],
                );
              },
              loading: () =>
                  const Center(child: CupertinoActivityIndicator()),
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
}

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({required this.workout, required this.unitSystem});

  final CardioWorkout workout;
  final UnitSystem unitSystem;

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
          const SizedBox(height: AppSpacing.xs),
          if (workout.activityType.hasDistance)
            Text(
              Format.distance(workout.distanceMeters, unitSystem),
              style: AppTypography.title,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _subtitleText(),
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
        ],
      ),
    );
  }

  String _subtitleText() {
    final duration = Format.duration(workout.durationSeconds);
    if (!workout.activityType.hasDistance || workout.distanceMeters <= 0) {
      return duration;
    }
    return '$duration  ·  ${Format.pace(workout.durationSeconds, workout.distanceMeters, unitSystem)}';
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.routePoints});

  final List<CardioRoutePoint> routePoints;

  @override
  Widget build(BuildContext context) {
    if (routePoints.length < 2) {
      return Container(
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
    }

    final routeLatLngPoints = routePoints
        .map((routePoint) => LatLng(routePoint.latitude, routePoint.longitude))
        .toList();

    return Container(
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
                urlTemplate:
                    '${dotenv.env['TILE_PROXY_URL'] ?? 'https://tile.openstreetmap.org'}/tiles/{z}/{x}/{y}.png',
                tileProvider: LoggingCacheTileProvider(
                  dotenv.env['TILE_PROXY_URL'] ??
                      'https://tile.openstreetmap.org',
                ),
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
}
