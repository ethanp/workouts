import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/services.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/models/cardio_workout_fingerprint.dart';
import 'package:workouts/models/cardio_workout_series.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:workouts/services/health_kit_bridge.dart';
import 'package:workouts/services/repositories/best_effort_store.dart';
import 'package:workouts/services/repositories/cardio_import.dart';
import 'package:workouts/services/repositories/cardio_metrics_store.dart';
import 'package:workouts/models/distance_bucket.dart';
import 'package:workouts/models/workout_history.dart';

part 'cardio_repository_powersync.g.dart';

const _log = ELogger('CardioRepository');
const _zoneHeartRatePageSize = 8;

class CardioRepositoryPowerSync(final PowerSyncDatabase _powerSync) {
  late final CardioMetricsStore _metricsStore = CardioMetricsStore(_powerSync);
  late final BestEffortStore _bestEffortStore = BestEffortStore(_powerSync);
  late final CardioImporter _importer = CardioImporter(_powerSync);

  static const _workoutSelectSql = '''
        SELECT
          w.*,
          COALESCE(m.zone1_seconds, 0) AS zone1_seconds,
          COALESCE(m.zone2_seconds, 0) AS zone2_seconds,
          COALESCE(m.zone3_seconds, 0) AS zone3_seconds,
          COALESCE(m.zone4_seconds, 0) AS zone4_seconds,
          COALESCE(m.zone5_seconds, 0) AS zone5_seconds,
          COALESCE(m.has_hr_samples, 0) AS has_hr_samples,
          m.pace_seconds_per_mile,
          m.meters_per_heartbeat,
          m.cardiac_drift_percent,
          COALESCE(m.has_distance_samples, 0) AS has_distance_samples,
          m.distance_origin,
          m.fitness_confidence
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
''';

  static String get _onOrAfterFirstDay =>
      "DATE(w.started_at, 'localtime') >= '${WorkoutHistory.firstDayKey}'";

  Stream<List<CardioWorkout>> watchCardioWorkouts() => _powerSync
      .watch(
        '$_workoutSelectSql WHERE $_onOrAfterFirstDay ORDER BY w.started_at DESC',
        triggerOnTables: const {'cardio_workouts', 'cardio_computed_metrics'},
      )
      .map((workoutRows) => workoutRows.mapL(CardioWorkout.fromRow));

  Future<CardioWorkout?> getWorkout(String workoutId) async {
    final workoutRows = await _powerSync.execute(
      '$_workoutSelectSql WHERE w.id = ?',
      [workoutId],
    );
    if (workoutRows.isEmpty) return null;
    return CardioWorkout.fromRow(workoutRows.first);
  }

  Stream<List<CardioWorkoutEvent>> watchWorkoutEvents(String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_workout_events WHERE workout_id = ? ORDER BY occurred_at ASC',
            parameters: [workoutId],
          )
          .map((eventRows) => eventRows.mapL(CardioWorkoutEvent.fromRow));

  Stream<List<CardioBestEffort>> watchBestEfforts() => _powerSync
      .watch(
        '''
        SELECT be.distance_meters, be.elapsed_seconds, w.started_at, w.activity_type
        FROM cardio_best_efforts be
        JOIN cardio_workouts w ON w.id = be.workout_id
        WHERE $_onOrAfterFirstDay
        ORDER BY w.started_at ASC
        ''',
        triggerOnTables: const {'cardio_best_efforts', 'cardio_workouts'},
      )
      .map((rows) {
        final bestEfforts = <CardioBestEffort>[];
        for (final row in rows) {
          final distanceMeters = (row['distance_meters'] as num).toDouble();
          if (DistanceBucket.fromMeters(distanceMeters) != null) {
            bestEfforts.add(CardioBestEffort.fromRow(row));
          }
        }
        return bestEfforts;
      });

  Stream<List<CardioCalendarDay>> watchCalendarDays() => _powerSync
      .watch(
        '''
        SELECT
          DATE(w.started_at, 'localtime') AS day,
          COALESCE(SUM(CASE WHEN w.activity_type = 'outdoorRun' THEN w.distance_meters END), 0) AS outdoor_run_distance_meters,
          SUM(w.duration_seconds)           AS total_duration_seconds,
          COALESCE(SUM(m.zone1_seconds), 0) AS total_zone1_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          COALESCE(SUM(m.zone3_seconds), 0) AS total_zone3_seconds,
          COALESCE(SUM(m.zone4_seconds), 0) AS total_zone4_seconds,
          COALESCE(SUM(m.zone5_seconds), 0) AS total_zone5_seconds,
          MAX(COALESCE(m.has_hr_samples, 0)) AS has_hr_data,
          COUNT(w.id)                       AS workout_count
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        WHERE $_onOrAfterFirstDay
        GROUP BY day
        ORDER BY day ASC
        ''',
        triggerOnTables: const {'cardio_workouts', 'cardio_computed_metrics'},
      )
      .map((dayRows) => dayRows.mapL(CardioCalendarDay.fromRow));

  Future<List<CardioWorkout>> getWorkoutsForDate(DateTime localDate) async {
    final String dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> workoutRows = await _powerSync.execute(
      "$_workoutSelectSql WHERE DATE(w.started_at, 'localtime') = ? "
      'AND $_onOrAfterFirstDay '
      'ORDER BY w.started_at ASC',
      [dayString],
    );
    return workoutRows.mapL(CardioWorkout.fromRow);
  }

  Future<void> deleteWorkout(String workoutId) async {
    await _powerSync.writeTransaction((transaction) async {
      await transaction.execute(
        'DELETE FROM cardio_route_points WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_heart_rate_samples WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_best_efforts WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_distance_samples WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_step_samples WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_workout_events WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_computed_metrics WHERE id = ?',
        [workoutId],
      );
      await transaction.execute('DELETE FROM cardio_workouts WHERE id = ?', [
        workoutId,
      ]);
    });
    _log.log('Deleted workout $workoutId (queued for upload).');
  }

  Future<void> wipeImportedCardio() => _importer.wipeStoredCardio();

  Future<int> dropWorkoutsBeforeFirstConsideredDay() =>
      _importer.dropWorkoutsBeforeFirstConsideredDay();

  Future<CardioWorkoutFingerprintIndex> storedAppleHealthFingerprints() =>
      _importer.storedAppleHealthFingerprints();

  Future<int> deleteAppleHealthWorkoutsMissingFrom(
    Set<String> seenExternalIds,
  ) => _importer.deleteAppleHealthWorkoutsMissingFrom(seenExternalIds);

  Future<bool> insertImportedWorkout(Map<String, dynamic> payload) =>
      _importer.insertRawWorkout(payload);

  Future<int> replaceImportedWorkouts(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
  }) => _importer.replaceAll(payloads, onProgress: onProgress);

  Future<void> persistDerivedFromHealthKitSeries({
    required CardioWorkout workout,
    required CardioWorkoutSeries series,
  }) async {
    await _metricsStore.persistFromHealthKitSeries(
      workout: workout,
      series: series,
    );
    await _bestEffortStore.computeFromSeries(workout.id, series);
  }

  Future<ZoneComputeOutcome> backfillMissingZonesNewestFirst(
    HealthKitBridge healthKit, {
    void Function(int done, int total)? onProgress,
  }) async {
    final workoutRows = await _powerSync.execute('''
      SELECT w.* FROM cardio_workouts w
      LEFT JOIN cardio_computed_metrics m ON m.id = w.id
      WHERE ${CardioMetricsStore.workoutsNeedingZoneComputeWhere}
      ORDER BY w.started_at DESC
    ''');
    var wroteFromHeartRate = 0;
    var markedUnreadable = 0;
    var leftMissing = 0;
    String? failureMessage;
    for (
      var pageStart = 0;
      pageStart < workoutRows.length;
      pageStart += _zoneHeartRatePageSize
    ) {
      final pageEnd = pageStart + _zoneHeartRatePageSize > workoutRows.length
          ? workoutRows.length
          : pageStart + _zoneHeartRatePageSize;
      final healthUnavailable = await _computeZonePage(
        healthKit,
        workoutRows.sublist(pageStart, pageEnd),
        onWrote: () => wroteFromHeartRate++,
        onMarkedUnreadable: () => markedUnreadable++,
        onLeftMissing: () => leftMissing++,
      );
      onProgress?.call(pageEnd, workoutRows.length);
      if (healthUnavailable) {
        failureMessage = "Apple Health isn't available on this device.";
        break;
      }
    }
    if (failureMessage == null && leftMissing > 0) {
      final workouts = leftMissing == 1 ? 'workout' : 'workouts';
      failureMessage = "Couldn't read heart rate for $leftMissing $workouts.";
    }
    return ZoneComputeOutcome(
      wroteFromHeartRate: wroteFromHeartRate,
      markedUnreadable: markedUnreadable,
      failureMessage: failureMessage,
    );
  }

  Future<bool> _computeZonePage(
    HealthKitBridge healthKit,
    List<Map<String, dynamic>> workoutRows, {
    required void Function() onWrote,
    required void Function() onMarkedUnreadable,
    required void Function() onLeftMissing,
  }) async {
    final outcomes = await Future.wait([
      for (final workoutRow in workoutRows)
        _computeZonesForWorkout(healthKit, CardioWorkout.fromRow(workoutRow)),
    ]);
    var healthUnavailable = false;
    for (final outcome in outcomes) {
      switch (outcome) {
        case _ZoneWorkoutWrite.heartRate:
          onWrote();
        case _ZoneWorkoutWrite.markedEmpty:
          onMarkedUnreadable();
        case _ZoneWorkoutWrite.leftMissing:
          onLeftMissing();
        case _ZoneWorkoutWrite.healthUnavailable:
          healthUnavailable = true;
      }
    }
    return healthUnavailable;
  }

  Future<_ZoneWorkoutWrite> _computeZonesForWorkout(
    HealthKitBridge healthKit,
    CardioWorkout workout,
  ) async {
    try {
      final heartRateSamples = await healthKit.fetchCardioHeartRateForZones(
        workoutId: workout.id,
        externalWorkoutId: workout.externalWorkoutId,
      );
      await _metricsStore.persistZoneTimeFromHeartRate(
        workoutId: workout.id,
        heartRateSamples: heartRateSamples,
      );
      return _ZoneWorkoutWrite.heartRate;
    } on PlatformException catch (error) {
      if (error.code == 'health_data_unavailable') {
        return _ZoneWorkoutWrite.healthUnavailable;
      }
      final existingMetrics = await _powerSync.getOptional(
        'SELECT id FROM cardio_computed_metrics WHERE id = ?',
        [workout.id],
      );
      if (existingMetrics != null) return _ZoneWorkoutWrite.leftMissing;
      await _metricsStore.persistZoneTimeFromHeartRate(
        workoutId: workout.id,
        heartRateSamples: const [],
      );
      return _ZoneWorkoutWrite.markedEmpty;
    }
  }

  Stream<int> watchWorkoutsMissingMetricsCount() =>
      _metricsStore.watchMissingCount();
}

@riverpod
CardioRepositoryPowerSync cardioRepositoryPowerSync(Ref ref) {
  final PowerSyncDatabase? powerSync = ref
      .watch(powerSyncDatabaseProvider)
      .value;
  if (powerSync == null) {
    throw StateError('PowerSync database not initialized');
  }
  return CardioRepositoryPowerSync(powerSync);
}

enum _ZoneWorkoutWrite() {
  heartRate,
  markedEmpty,
  leftMissing,
  healthUnavailable,
}

class const ZoneComputeOutcome({
  required final int wroteFromHeartRate,
  required final int markedUnreadable,
  final String? failureMessage,
});

class ZoneComputeFailed(final String message) implements Exception {
  @override
  String toString() => message;
}
