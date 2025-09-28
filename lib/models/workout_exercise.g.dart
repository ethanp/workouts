// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutExerciseImpl _$$WorkoutExerciseImplFromJson(
  Map<String, dynamic> json,
) => _$WorkoutExerciseImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  modality: $enumDecode(_$ExerciseModalityEnumMap, json['modality']),
  prescription: json['prescription'] as String,
  targetSets: (json['targetSets'] as num?)?.toInt() ?? 1,
  equipment: json['equipment'] as String?,
  cue: json['cue'] as String?,
);

Map<String, dynamic> _$$WorkoutExerciseImplToJson(
  _$WorkoutExerciseImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'modality': _$ExerciseModalityEnumMap[instance.modality]!,
  'prescription': instance.prescription,
  'targetSets': instance.targetSets,
  'equipment': instance.equipment,
  'cue': instance.cue,
};

const _$ExerciseModalityEnumMap = {
  ExerciseModality.reps: 'reps',
  ExerciseModality.timed: 'timed',
  ExerciseModality.hold: 'hold',
  ExerciseModality.mobility: 'mobility',
  ExerciseModality.breath: 'breath',
};
