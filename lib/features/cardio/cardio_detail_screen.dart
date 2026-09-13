import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/cardio/workout_polarization_card.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_session_structure.dart';
import 'package:workouts/models/cardio_session_verdict.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/models/fitness_signal_confidence.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';
import 'package:workouts/widgets/logging_tile_provider.dart';

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
            _SessionVerdictCard(workout: latestWorkout),
            if (comparison.hasPeers) ...[
              const SizedBox(height: ELayout.spaceMd),
              _SameTypeComparisonCard(comparison: comparison),
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
      return _StairClimbStory(
        workout: latestWorkout,
        heartRateSamplesAsync: heartRateSamplesAsync,
        workoutEventsAsync: workoutEventsAsync,
      );
    }
    if (latestWorkout.activityType.hasRoute) {
      return _OutdoorWalkStory(
        workout: latestWorkout,
        routePointsAsync: routePointsAsync,
        heartRateSamplesAsync: heartRateSamplesAsync,
        workoutEventsAsync: workoutEventsAsync,
      );
    }
    return _MachineCardioStory(
      workout: latestWorkout,
      heartRateSamplesAsync: heartRateSamplesAsync,
      workoutEventsAsync: workoutEventsAsync,
    );
  }
}

class const _SessionVerdictCard({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final verdict = CardioSessionVerdict.fromWorkout(workout);
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(verdict.aerobicJob.label, style: EText.title),
          const SizedBox(height: ELayout.spaceXs),
          Text(_evidenceLine(verdict), style: EText.section),
          const SizedBox(height: ELayout.spaceSm),
          Wrap(
            spacing: ELayout.spaceSm,
            runSpacing: ELayout.spaceXs,
            children: [
              if (workout.zoneTime.total > 0) _zoneChip(verdict),
              if (workout.averageHeartRateBpm != null)
                Text(
                  '${workout.averageHeartRateBpm!.round()} bpm',
                  style: EText.body.medium.copyWith(
                    color: EColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ELayout.spaceSm),
          Text(
            workout.shortProvenanceCaption,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          Text(
            Format.dateTime(workout.startedAt),
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _evidenceLine(CardioSessionVerdict verdict) {
    final parts = <String>[Format.duration(workout.durationSeconds)];
    if (verdict.primaryWork.headline.isNotEmpty) {
      parts.add(verdict.primaryWork.headline);
    }
    final supporting = verdict.primaryWork.supporting;
    if (supporting != null && supporting.isNotEmpty) {
      parts.add(supporting);
    }
    return parts.join('  ·  ');
  }

  Widget _zoneChip(CardioSessionVerdict verdict) {
    final zoneColor = HrZonePalette.zoneColors[verdict.dominantZoneIndex];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: zoneColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        HrZonePalette.zoneNames[verdict.dominantZoneIndex],
        style: EText.caption.copyWith(
          color: zoneColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class const _SameTypeComparisonCard({
  required final SameTypeWorkoutComparison comparison,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent ${comparison.thisWorkout.activityType.displayName}',
            style: EText.section,
          ),
          const SizedBox(height: ELayout.spaceSm),
          for (final peer in comparison.peers) _peerRow(peer),
        ],
      ),
    );
  }

  Widget _peerRow(CardioWorkout peer) {
    final isThisWorkout = peer.id == comparison.thisWorkout.id;
    final primaryWork = CardioSessionVerdict.fromWorkout(peer).primaryWork;
    final workCaption = primaryWork.headline.isEmpty
        ? '—'
        : primaryWork.headline;
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
      child: Text(
        '${Format.dateIso(peer.startedAt)}  ·  '
        '${Format.durationShort(peer.durationSeconds)}  ·  '
        '${_avgHr(peer)}  ·  '
        '$workCaption  ·  '
        '${peer.zoneTime.gteZone2Minutes}m Z2–5'
        '${_metsSuffix(peer)}',
        style: EText.caption.copyWith(
          color: isThisWorkout ? EColors.textPrimary : EColors.textTertiary,
          fontWeight: isThisWorkout ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  String _avgHr(CardioWorkout peer) {
    final averageHeartRateBpm = peer.averageHeartRateBpm;
    if (averageHeartRateBpm == null) return '— bpm';
    return '${averageHeartRateBpm.round()} bpm';
  }

  String _metsSuffix(CardioWorkout peer) {
    final averageMets = peer.averageMets;
    if (averageMets == null) return '';
    return '  ·  ${Format.mets(averageMets)}';
  }
}

class const _OutdoorWalkStory({
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
          data: (routePoints) => _RouteCard(routePoints: routePoints),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            'Unable to load route: $error',
            style: EText.body.medium.copyWith(color: EColors.danger),
          ),
        ),
        _ElevationCaption(workout: workout, indoorIncline: false),
        _HeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: routePointsAsync.asData?.value ?? const [],
        ),
        _SessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }
}

class const _MachineCardioStory({
  required final CardioWorkout workout,
  required final AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _machineNotes(),
        _HeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: const [],
        ),
        _SessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }

  Widget _machineNotes() {
    final notes = <String>[];
    if (workout.activityType == CardioType.elliptical) {
      _addDifferingMachineDuration(notes);
    } else {
      _addIndoorWalkRunNotes(notes);
    }
    _addEarnedFitnessNotes(notes);
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceMd),
      child: _DetailCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
                child: Text(note, style: EText.caption.copyWith(
                  color: EColors.textSecondary,
                )),
              ),
          ],
        ),
      ),
    );
  }

  void _addDifferingMachineDuration(List<String> notes) {
    final machineDurationSeconds = workout.fitnessMachineDurationSeconds;
    if (machineDurationSeconds == null) return;
    if ((machineDurationSeconds - workout.durationSeconds).abs() < 5) return;
    notes.add(
      'Machine duration ${Format.duration(machineDurationSeconds.round())}',
    );
  }

  void _addIndoorWalkRunNotes(List<String> notes) {
    final stepCount = workout.stepCount;
    if (stepCount != null && stepCount > 0) {
      notes.add(Format.steps(stepCount));
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

class const _StairClimbStory({
  required final CardioWorkout workout,
  required final AsyncValue<List<CardioHeartRateSample>> heartRateSamplesAsync,
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stairNotes(),
        _HeartRateAndZones(
          heartRateSamplesAsync: heartRateSamplesAsync,
          routePoints: const [],
        ),
        _SessionStructureCard(workoutEventsAsync: workoutEventsAsync),
      ],
    );
  }

  Widget _stairNotes() {
    final notes = <String>[];
    final flightsClimbed = workout.flightsClimbed;
    if (flightsClimbed != null && flightsClimbed > 0) {
      notes.add(Format.flights(flightsClimbed));
    }
    final stepCount = workout.stepCount;
    if (stepCount != null && stepCount > 0) {
      notes.add(Format.steps(stepCount));
    }
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceMd),
      child: _DetailCard(
        child: Text(
          notes.join('  ·  '),
          style: EText.body.medium.copyWith(color: EColors.textSecondary),
        ),
      ),
    );
  }
}

class const _HeartRateAndZones({
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
            _heartRateCard(cardioHeartRateSamples),
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

  Widget _heartRateCard(List<CardioHeartRateSample> cardioHeartRateSamples) {
    return CardioMetricsCard(
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
    );
  }
}

class const _SessionStructureCard({
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return workoutEventsAsync.when(
      data: (workoutEvents) {
        final structure = CardioSessionStructure.fromEvents(workoutEvents);
        if (structure.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: ELayout.spaceMd),
          child: _DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session', style: EText.section),
                const SizedBox(height: ELayout.spaceSm),
                for (final caption in structure.captions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
                    child: Text(
                      caption,
                      style: EText.caption.copyWith(
                        color: EColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class const _RouteCard({required final List<CardioRoutePoint> routePoints})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routePoints.length < 2) return _noRouteCard();
    final routeLatLngPoints = [
      for (final routePoint in routePoints)
        LatLng(routePoint.latitude, routePoint.longitude),
    ];
    return _routeMapCard(routeLatLngPoints, ref.watch(tileProxyUrlProvider));
  }

  Widget _noRouteCard() => _DetailCard(
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

class const _ElevationCaption({
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
            : Format.elevation(elevationAscendedMeters),
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    );
  }
}

class const _DetailCard({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: child,
    );
  }
}
