// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutBlockImpl _$$WorkoutBlockImplFromJson(Map<String, dynamic> json) =>
    _$WorkoutBlockImpl(
      id: json['id'] as String,
      type: $enumDecode(_$WorkoutBlockTypeEnumMap, json['type']),
      title: json['title'] as String,
      targetDuration: Duration(
        microseconds: (json['targetDuration'] as num).toInt(),
      ),
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String? ?? '',
    );

Map<String, dynamic> _$$WorkoutBlockImplToJson(_$WorkoutBlockImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$WorkoutBlockTypeEnumMap[instance.type]!,
      'title': instance.title,
      'targetDuration': instance.targetDuration.inMicroseconds,
      'exercises': instance.exercises,
      'description': instance.description,
    };

const _$WorkoutBlockTypeEnumMap = {
  WorkoutBlockType.warmup: 'warmup',
  WorkoutBlockType.animalFlow: 'animalFlow',
  WorkoutBlockType.strength: 'strength',
  WorkoutBlockType.mobility: 'mobility',
  WorkoutBlockType.cooldown: 'cooldown',
};
