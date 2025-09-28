// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionSetLogImpl _$$SessionSetLogImplFromJson(Map<String, dynamic> json) =>
    _$SessionSetLogImpl(
      id: json['id'] as String,
      sessionBlockId: json['sessionBlockId'] as String,
      exerciseId: json['exerciseId'] as String,
      setIndex: (json['setIndex'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      duration: const NullableDurationSecondsConverter().fromJson(
        (json['duration'] as num?)?.toInt(),
      ),
      rpe: (json['rpe'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$SessionSetLogImplToJson(_$SessionSetLogImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionBlockId': instance.sessionBlockId,
      'exerciseId': instance.exerciseId,
      'setIndex': instance.setIndex,
      'weightKg': instance.weightKg,
      'reps': instance.reps,
      'duration': const NullableDurationSecondsConverter().toJson(
        instance.duration,
      ),
      'rpe': instance.rpe,
      'notes': instance.notes,
    };

_$SessionBlockImpl _$$SessionBlockImplFromJson(Map<String, dynamic> json) =>
    _$SessionBlockImpl(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      type: $enumDecode(_$WorkoutBlockTypeEnumMap, json['type']),
      blockIndex: (json['blockIndex'] as num).toInt(),
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      logs: (json['logs'] as List<dynamic>)
          .map((e) => SessionSetLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      targetDuration: const DurationSecondsConverter().fromJson(
        (json['targetDuration'] as num).toInt(),
      ),
      actualDuration: const NullableDurationSecondsConverter().fromJson(
        (json['actualDuration'] as num?)?.toInt(),
      ),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$SessionBlockImplToJson(_$SessionBlockImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'type': _$WorkoutBlockTypeEnumMap[instance.type]!,
      'blockIndex': instance.blockIndex,
      'exercises': instance.exercises,
      'logs': instance.logs,
      'targetDuration': const DurationSecondsConverter().toJson(
        instance.targetDuration,
      ),
      'actualDuration': const NullableDurationSecondsConverter().toJson(
        instance.actualDuration,
      ),
      'notes': instance.notes,
    };

const _$WorkoutBlockTypeEnumMap = {
  WorkoutBlockType.warmup: 'warmup',
  WorkoutBlockType.animalFlow: 'animalFlow',
  WorkoutBlockType.strength: 'strength',
  WorkoutBlockType.mobility: 'mobility',
  WorkoutBlockType.cooldown: 'cooldown',
};

_$BreathSegmentImpl _$$BreathSegmentImplFromJson(Map<String, dynamic> json) =>
    _$BreathSegmentImpl(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      pattern: json['pattern'] as String,
      targetDuration: const DurationSecondsConverter().fromJson(
        (json['targetDuration'] as num).toInt(),
      ),
      actualDuration: const NullableDurationSecondsConverter().fromJson(
        (json['actualDuration'] as num?)?.toInt(),
      ),
    );

Map<String, dynamic> _$$BreathSegmentImplToJson(_$BreathSegmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'pattern': instance.pattern,
      'targetDuration': const DurationSecondsConverter().toJson(
        instance.targetDuration,
      ),
      'actualDuration': const NullableDurationSecondsConverter().toJson(
        instance.actualDuration,
      ),
    };

_$SessionImpl _$$SessionImplFromJson(Map<String, dynamic> json) =>
    _$SessionImpl(
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      duration: const NullableDurationSecondsConverter().fromJson(
        (json['duration'] as num?)?.toInt(),
      ),
      notes: json['notes'] as String?,
      feeling: json['feeling'] as String?,
      blocks: (json['blocks'] as List<dynamic>)
          .map((e) => SessionBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      breathSegments: (json['breathSegments'] as List<dynamic>)
          .map((e) => BreathSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      isPaused: json['isPaused'] as bool? ?? false,
      pausedAt: json['pausedAt'] == null
          ? null
          : DateTime.parse(json['pausedAt'] as String),
      totalPausedDuration: json['totalPausedDuration'] == null
          ? Duration.zero
          : const DurationSecondsConverter().fromJson(
              (json['totalPausedDuration'] as num).toInt(),
            ),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$SessionImplToJson(_$SessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'templateId': instance.templateId,
      'startedAt': instance.startedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'duration': const NullableDurationSecondsConverter().toJson(
        instance.duration,
      ),
      'notes': instance.notes,
      'feeling': instance.feeling,
      'blocks': instance.blocks,
      'breathSegments': instance.breathSegments,
      'isPaused': instance.isPaused,
      'pausedAt': instance.pausedAt?.toIso8601String(),
      'totalPausedDuration': const DurationSecondsConverter().toJson(
        instance.totalPausedDuration,
      ),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
