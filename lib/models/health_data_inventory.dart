import 'dart:convert';

import 'package:workouts/models/cardio_type.dart';

class const HealthShareStatus({
  required final String id,
  required final String shareStatus,
  required final String note,
}) {
  factory fromMap(Map<String, dynamic> statusMap) {
    return HealthShareStatus(
      id: (statusMap['id'] as String?) ?? 'unknown',
      shareStatus: (statusMap['shareStatus'] as String?) ?? 'unknown',
      note:
          (statusMap['note'] as String?) ??
          'HealthKit reports share permission only; read denial is not visible to apps.',
    );
  }

  Map<String, Object> get asJson => {
    'id': id,
    'shareStatus': shareStatus,
    'note': note,
  };
}

class const HealthSignalSummary({
  required final String type,
  required final int sampleCount,
  required final bool hasCondensed,
  required final int coverageSeconds,
  required final bool associated,
  final String kind = 'quantity',
}) {
  factory fromMap(Map<String, dynamic> signalMap) {
    return HealthSignalSummary(
      type: (signalMap['type'] as String?) ?? 'unknown',
      sampleCount: _asInt(signalMap['sampleCount']) ?? 0,
      hasCondensed: signalMap['hasCondensed'] == true,
      coverageSeconds: _asInt(signalMap['coverageSeconds']) ?? 0,
      associated: signalMap['associated'] == true,
      kind: (signalMap['kind'] as String?) ?? 'quantity',
    );
  }

  bool get isPresent => sampleCount > 0;

  String get shortType => type.shortHealthKitType;

  Map<String, Object> get asJson => {
    'type': type,
    'kind': kind,
    'sampleCount': sampleCount,
    'hasCondensed': hasCondensed,
    'coverageSeconds': coverageSeconds,
    'associated': associated,
  };
}

class const HealthWorkoutStatistic({
  required final String type,
  required final String source,
  final String? unit,
  final double? average,
  final double? min,
  final double? max,
  final double? sum,
  final double? mostRecent,
}) {
  factory fromMap(Map<String, dynamic> statisticMap) {
    return HealthWorkoutStatistic(
      type: (statisticMap['type'] as String?) ?? 'unknown',
      source: (statisticMap['source'] as String?) ?? 'workoutStatistics',
      unit: statisticMap['unit'] as String?,
      average: _asDouble(statisticMap['average']),
      min: _asDouble(statisticMap['min']),
      max: _asDouble(statisticMap['max']),
      sum: _asDouble(statisticMap['sum']),
      mostRecent: _asDouble(statisticMap['mostRecent']),
    );
  }

  String get shortType => type.shortHealthKitType;

  Map<String, Object?> get asJson => {
    'type': type,
    'source': source,
    'unit': unit,
    'average': average,
    'min': min,
    'max': max,
    'sum': sum,
    'mostRecent': mostRecent,
  };
}

class const HealthInventoryEvent({
  required final String type,
  required final DateTime timestamp,
  final DateTime? endedAt,
  final Map<String, String> metadata = const {},
}) {
  factory fromMap(Map<String, dynamic> eventMap) {
    return HealthInventoryEvent(
      type: (eventMap['type'] as String?) ?? 'other',
      timestamp:
          DateTime.tryParse(eventMap['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse(eventMap['endTimestamp'] as String? ?? ''),
      metadata: _stringMap(eventMap['metadata']),
    );
  }

  Map<String, Object?> get asJson => {
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'metadata': metadata,
  };
}

class const HealthInventoryActivity({
  required final String activityType,
  required final int activityTypeRaw,
  required final DateTime startedAt,
  final DateTime? endedAt,
  final int durationSeconds = 0,
  final Map<String, String> metadata = const {},
  final List<HealthWorkoutStatistic> statistics = const [],
}) {
  factory fromMap(Map<String, dynamic> activityMap) {
    return HealthInventoryActivity(
      activityType: (activityMap['activityType'] as String?) ?? 'unknown',
      activityTypeRaw: _asInt(activityMap['activityTypeRaw']) ?? 0,
      startedAt:
          DateTime.tryParse(activityMap['startDate'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: DateTime.tryParse(activityMap['endDate'] as String? ?? ''),
      durationSeconds: _asInt(activityMap['durationSeconds']) ?? 0,
      metadata: _stringMap(activityMap['metadata']),
      statistics: _statistics(activityMap['statistics']),
    );
  }

  Map<String, Object?> get asJson => {
    'activityType': activityType,
    'activityTypeRaw': activityTypeRaw,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'metadata': metadata,
    'statistics': [for (final statistic in statistics) statistic.asJson],
  };
}

class const HealthInventoryWorkout({
  required final String externalWorkoutId,
  required final CardioType activityType,
  required final DateTime startedAt,
  required final DateTime endedAt,
  required final int durationSeconds,
  required final String sourceName,
  final String? sourceBundleId,
  final String? deviceName,
  final String? deviceModel,
  final bool machineLinked = false,
  final double? distanceMeters,
  final double? energyKcal,
  final double? averageHeartRateBpm,
  final double? elevationAscendedMeters,
  final double? recoveryBpm,
  final double? effortScore,
  final double? estimatedEffortScore,
  final List<String> metadataKeys = const [],
  final Map<String, String> metadata = const {},
  final List<HealthInventoryEvent> events = const [],
  final List<HealthSignalSummary> signals = const [],
  final List<HealthWorkoutStatistic> statistics = const [],
  final List<HealthInventoryActivity> activities = const [],
}) {
  factory fromMap(Map<String, dynamic> workoutMap) {
    final startDate = DateTime.tryParse(workoutMap['startDate'] as String? ?? '');
    final endDate = DateTime.tryParse(workoutMap['endDate'] as String? ?? '');
    return HealthInventoryWorkout(
      externalWorkoutId: (workoutMap['externalWorkoutId'] as String?) ?? '',
      activityType: CardioType.fromDbKey(
        (workoutMap['activityType'] as String?) ?? CardioType.outdoorRun.dbKey,
      ),
      startedAt: startDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: endDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      durationSeconds: _asInt(workoutMap['durationSeconds']) ?? 0,
      sourceName: (workoutMap['sourceName'] as String?) ?? 'Apple Health',
      sourceBundleId: workoutMap['sourceBundleId'] as String?,
      deviceName: workoutMap['deviceName'] as String?,
      deviceModel: workoutMap['deviceModel'] as String?,
      machineLinked: workoutMap['machineLinked'] == true,
      distanceMeters: _asDouble(workoutMap['distanceMeters']),
      energyKcal: _asDouble(workoutMap['energyKcal']),
      averageHeartRateBpm: _asDouble(workoutMap['avgHeartRateBpm']),
      elevationAscendedMeters: _asDouble(workoutMap['elevationAscendedMeters']),
      recoveryBpm: _asDouble(workoutMap['recoveryBpm']),
      effortScore: _asDouble(workoutMap['effortScore']),
      estimatedEffortScore: _asDouble(workoutMap['estimatedEffortScore']),
      metadataKeys: _stringList(workoutMap['metadataKeys']),
      metadata: _stringMap(workoutMap['metadata']),
      events: _events(workoutMap['events']),
      signals: _signals(workoutMap['signals']),
      statistics: _statistics(workoutMap['statistics']),
      activities: _activities(workoutMap['activities']),
    );
  }

  List<String> get eventTypes =>
      {for (final event in events) event.type}.toList()..sort();

  String get sourceKey =>
      '$sourceName · ${deviceName ?? deviceModel ?? 'no device'}';

  Map<String, Object?> get asJson => {
    'externalWorkoutId': externalWorkoutId,
    'activityType': activityType.dbKey,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'sourceName': sourceName,
    'sourceBundleId': sourceBundleId,
    'deviceName': deviceName,
    'deviceModel': deviceModel,
    'machineLinked': machineLinked,
    'distanceMeters': distanceMeters,
    'energyKcal': energyKcal,
    'averageHeartRateBpm': averageHeartRateBpm,
    'elevationAscendedMeters': elevationAscendedMeters,
    'recoveryBpm': recoveryBpm,
    'effortScore': effortScore,
    'estimatedEffortScore': estimatedEffortScore,
    'metadataKeys': metadataKeys,
    'metadata': metadata,
    'events': [for (final event in events) event.asJson],
    'signals': [for (final signal in signals) signal.asJson],
    'statistics': [for (final statistic in statistics) statistic.asJson],
    'activities': [for (final activity in activities) activity.asJson],
  };
}

class const HealthSourceMatrixRow({
  required final String sourceKey,
  required final CardioType activityType,
  required final bool machineLinked,
  required final int workoutCount,
  required final List<String> signalsPresent,
}) {
  String get cohortLabel =>
      machineLinked ? 'Machine-linked' : 'Watch estimate';

  Map<String, Object> get asJson => {
    'sourceKey': sourceKey,
    'activityType': activityType.dbKey,
    'machineLinked': machineLinked,
    'workoutCount': workoutCount,
    'signalsPresent': signalsPresent,
  };
}

class const HealthDataInventory({
  required final List<HealthShareStatus> requestedTypes,
  required final List<HealthInventoryWorkout> workouts,
  final List<String> queriedQuantityTypes = const [],
  final List<String> queriedCategoryTypes = const [],
}) {
  factory fromMap(Map<String, dynamic> inventoryMap) {
    return HealthDataInventory(
      requestedTypes: _shareStatuses(inventoryMap['requestedTypes']),
      workouts: _workouts(inventoryMap['workouts']),
      queriedQuantityTypes: _stringList(inventoryMap['queriedQuantityTypes']),
      queriedCategoryTypes: _stringList(inventoryMap['queriedCategoryTypes']),
    );
  }

  List<HealthSourceMatrixRow> get sourceMatrix {
    final grouped = <String, List<HealthInventoryWorkout>>{};
    for (final workout in workouts) {
      final key = '${workout.sourceKey}|${workout.activityType.dbKey}';
      (grouped[key] ??= []).add(workout);
    }
    return grouped.values.map((sourceWorkouts) {
      final first = sourceWorkouts.first;
      final present = <String>{};
      for (final workout in sourceWorkouts) {
        for (final signal in workout.signals) {
          if (signal.isPresent) present.add(signal.shortType);
        }
        for (final statistic in workout.statistics) {
          present.add(statistic.shortType);
        }
        for (final activity in workout.activities) {
          for (final statistic in activity.statistics) {
            present.add(statistic.shortType);
          }
        }
        present.addAll(workout.metadata.keys);
        if (workout.recoveryBpm != null) {
          present.add('heartRateRecoveryOneMinute');
        }
        if (workout.effortScore != null || workout.estimatedEffortScore != null) {
          present.add('workoutEffortScore');
        }
        if ((workout.distanceMeters ?? 0) > 0) present.add('summaryDistance');
        if (workout.events.isNotEmpty) present.add('workoutEvents');
      }
      return HealthSourceMatrixRow(
        sourceKey: first.sourceKey,
        activityType: first.activityType,
        machineLinked: sourceWorkouts.any((workout) => workout.machineLinked),
        workoutCount: sourceWorkouts.length,
        signalsPresent: present.toList()..sort(),
      );
    }).toList()..sort((left, right) {
      final sourceOrder = left.sourceKey.compareTo(right.sourceKey);
      if (sourceOrder != 0) return sourceOrder;
      return left.activityType.displayName.compareTo(right.activityType.displayName);
    });
  }

  Map<String, Object> get asJson => {
    'workoutCount': workouts.length,
    'queriedQuantityTypes': queriedQuantityTypes,
    'queriedCategoryTypes': queriedCategoryTypes,
    'requestedTypes': [for (final status in requestedTypes) status.asJson],
    'sourceMatrix': [for (final row in sourceMatrix) row.asJson],
    'workouts': [for (final workout in workouts) workout.asJson],
  };

  String get jsonEmailBody =>
      const JsonEncoder.withIndent('  ').convert(asJson);
}

class const HealthInventoryInspectProgress({
  required final String caption,
  final int completedWorkouts = 0,
  final int totalWorkouts = 0,
}) {
  factory fromMap(Map<String, dynamic> progressMap) {
    return HealthInventoryInspectProgress(
      caption: (progressMap['caption'] as String?) ?? 'Inspecting…',
      completedWorkouts: _asInt(progressMap['completedWorkouts']) ?? 0,
      totalWorkouts: _asInt(progressMap['totalWorkouts']) ?? 0,
    );
  }

  double get fraction {
    if (totalWorkouts <= 0) return 0;
    return (completedWorkouts / totalWorkouts).clamp(0.0, 1.0);
  }
}

class const HealthDataInventoryState({
  final HealthDataInventory? inventory,
  final HealthInventoryInspectProgress? inspectProgress,
  final String? errorMessage,
}) {
  bool get isInspecting => inspectProgress != null;
}

List<HealthShareStatus> _shareStatuses(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => HealthShareStatus.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

List<HealthInventoryWorkout> _workouts(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) => HealthInventoryWorkout.fromMap(Map<String, dynamic>.from(item)),
      )
      .toList();
}

List<HealthSignalSummary> _signals(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => HealthSignalSummary.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

List<HealthWorkoutStatistic> _statistics(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) =>
            HealthWorkoutStatistic.fromMap(Map<String, dynamic>.from(item)),
      )
      .toList();
}

List<HealthInventoryActivity> _activities(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) =>
            HealthInventoryActivity.fromMap(Map<String, dynamic>.from(item)),
      )
      .toList();
}

List<HealthInventoryEvent> _events(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => HealthInventoryEvent.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String) entry.key as String: '${entry.value}',
  };
}

extension HealthKitTypeName on String {
  String get shortHealthKitType {
    const prefixes = [
      'HKQuantityTypeIdentifier',
      'HKCategoryTypeIdentifier',
      'HKDataTypeIdentifier',
      'HKSeriesTypeIdentifier',
    ];
    for (final prefix in prefixes) {
      if (startsWith(prefix)) return substring(prefix.length);
    }
    return this;
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.round();
  return int.tryParse('$value');
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
