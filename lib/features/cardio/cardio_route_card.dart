import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:workouts/widgets/logging_tile_provider.dart';

import 'cardio_detail_card.dart';

class const CardioRouteCard({required final List<CardioRoutePoint> routePoints})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routePoints.length < 2) return const CardioNoRouteCard();
    final routeLatLngPoints = [
      for (final routePoint in routePoints)
        LatLng(routePoint.latitude, routePoint.longitude),
    ];
    return CardioRouteMapCard(
      routeLatLngPoints: routeLatLngPoints,
      tileProxyUrl: ref.watch(tileProxyUrlProvider),
    );
  }
}

class const CardioNoRouteCard() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CardioDetailCard(
      child: Text(
        'Route unavailable for this workout.',
        style: EText.body.medium.copyWith(color: EColors.textTertiary),
      ),
    );
  }
}

class const CardioRouteMapCard({
  required final List<LatLng> routeLatLngPoints,
  required final String tileProxyUrl,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class const CardioElevationCaption({
  required final CardioWorkout workout,
  required final bool indoorIncline,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final elevationAscendedMeters = workout.elevationAscendedMeters;
    if (elevationAscendedMeters == null || elevationAscendedMeters <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: ELayout.spaceSm),
      child: Text(
        indoorIncline
            ? '${elevationAscendedMeters.round()} m gain / incline'
            : workout.elevationGainCaption!,
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    );
  }
}
