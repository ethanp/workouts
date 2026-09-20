import 'dart:async';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/models/cardio_workout_series.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';

part 'cardio_browse_providers.g.dart';

Stream<T> _watchRepo<T>(
  Ref ref,
  Stream<T> Function(CardioRepositoryPowerSync) watchFn,
) {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) {
    final streamController = StreamController<T>();
    ref.onDispose(streamController.close);
    return streamController.stream;
  }
  return watchFn(CardioRepositoryPowerSync(powerSyncDatabase));
}

@riverpod
Stream<List<CardioWorkout>> cardioWorkouts(Ref ref) => _watchRepo(
  ref,
  (cardioRepository) => cardioRepository.watchCardioWorkouts(),
);

@riverpod
Stream<List<CardioCalendarDay>> cardioCalendarDays(Ref ref) =>
    _watchRepo(ref, (cardioRepository) => cardioRepository.watchCalendarDays());

@riverpod
Future<CardioWorkoutSeries> cardioWorkoutSeries(
  Ref ref,
  String workoutId,
) async {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) return CardioWorkoutSeries.empty;
  final cardioRepository = CardioRepositoryPowerSync(powerSyncDatabase);
  final workout = await cardioRepository.getWorkout(workoutId);
  if (workout == null || workout.externalWorkoutId.isEmpty) {
    return CardioWorkoutSeries.empty;
  }
  final series = await ref
      .read(healthKitBridgeProvider)
      .fetchCardioWorkoutSeries(
        workoutId: workout.id,
        externalWorkoutId: workout.externalWorkoutId,
      );
  try {
    await cardioRepository.persistDerivedFromHealthKitSeries(
      workout: workout,
      series: series,
    );
  } on StateError {
    return series;
  }
  return series;
}

@riverpod
Future<List<CardioRoutePoint>> cardioRoutePoints(
  Ref ref,
  String workoutId,
) async =>
    (await ref.watch(cardioWorkoutSeriesProvider(workoutId).future)).routePoints;

@riverpod
Future<List<CardioHeartRateSample>> cardioHeartRateSamples(
  Ref ref,
  String workoutId,
) async =>
    (await ref.watch(cardioWorkoutSeriesProvider(workoutId).future))
        .heartRateSamples;

@riverpod
Future<List<CardioQuantitySample>> cardioDistanceSamples(
  Ref ref,
  String workoutId,
) async =>
    (await ref.watch(cardioWorkoutSeriesProvider(workoutId).future))
        .distanceSamples;

@riverpod
Stream<List<CardioWorkoutEvent>> cardioWorkoutEvents(
  Ref ref,
  String workoutId,
) => _watchRepo(
  ref,
  (cardioRepository) => cardioRepository.watchWorkoutEvents(workoutId),
);

@riverpod
Stream<List<CardioBestEffort>> cardioBestEfforts(Ref ref) =>
    _watchRepo(ref, (cardioRepository) => cardioRepository.watchBestEfforts());

@riverpod
Stream<int> workoutsMissingMetricsCount(Ref ref) => _watchRepo(
  ref,
  (cardioRepository) => cardioRepository.watchWorkoutsMissingMetricsCount(),
);
