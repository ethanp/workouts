// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkoutTemplateImpl _$$WorkoutTemplateImplFromJson(
  Map<String, dynamic> json,
) => _$WorkoutTemplateImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  goal: json['goal'] as String,
  blocks: (json['blocks'] as List<dynamic>)
      .map((e) => WorkoutBlock.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$$WorkoutTemplateImplToJson(
  _$WorkoutTemplateImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'goal': instance.goal,
  'blocks': instance.blocks,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'notes': instance.notes,
};
