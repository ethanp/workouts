import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/heart_rate_timeline_card.dart';
import 'package:workouts/widgets/logging_tile_provider.dart';

class RunDetailScreen extends ConsumerWidget {
  const RunDetailScreen({super.key, required this.run});

  final FitnessRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routePointsAsync = ref.watch(runRoutePointsProvider(run.id));
    final heartRateSamplesAsync = ref.watch(runHeartRateSamplesProvider(run.id));
    final distanceKilometers = run.distanceMeters / 1000;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Run Detail')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _RunSummaryCard(run: run, distanceKilometers: distanceKilometers),
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
              data: (runHeartRateSamples) {
                final chartSamples = runHeartRateSamples
                    .map(
                      (runHeartRateSample) => HeartRateSample(
                        id: runHeartRateSample.id,
                        sessionId: runHeartRateSample.runId,
                        timestamp: runHeartRateSample.timestamp,
                        bpm: runHeartRateSample.bpm,
                        source: 'run_import',
                      ),
                    )
                    .toList();
                return HeartRateTimelineCard(
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

class _RunSummaryCard extends StatelessWidget {
  const _RunSummaryCard({required this.run, required this.distanceKilometers});

  final FitnessRun run;
  final double distanceKilometers;

  @override
  Widget build(BuildContext context) {
    final averagePaceSecondsPerKilometer = run.distanceMeters > 0
        ? run.durationSeconds / (run.distanceMeters / 1000)
        : 0.0;

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
          Text('${distanceKilometers.toStringAsFixed(2)} km', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_formatDuration(run.durationSeconds)}  ·  ${_formatPace(averagePaceSecondsPerKilometer)}',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int durationSeconds) {
    final duration = Duration(seconds: durationSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatPace(double pacePerKilometerSeconds) {
    if (pacePerKilometerSeconds <= 0) {
      return '--:-- /km';
    }
    final roundedSeconds = pacePerKilometerSeconds.round();
    final minutes = roundedSeconds ~/ 60;
    final seconds = roundedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.routePoints});

  final List<RunRoutePoint> routePoints;

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
          'Route unavailable for this run.',
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
