// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_exercise.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WorkoutExercise _$WorkoutExerciseFromJson(Map<String, dynamic> json) {
  return _WorkoutExercise.fromJson(json);
}

/// @nodoc
mixin _$WorkoutExercise {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  ExerciseModality get modality => throw _privateConstructorUsedError;
  String get prescription => throw _privateConstructorUsedError;
  int get targetSets => throw _privateConstructorUsedError;
  String? get equipment => throw _privateConstructorUsedError;
  String? get cue => throw _privateConstructorUsedError;

  /// Serializes this WorkoutExercise to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkoutExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkoutExerciseCopyWith<WorkoutExercise> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutExerciseCopyWith<$Res> {
  factory $WorkoutExerciseCopyWith(
    WorkoutExercise value,
    $Res Function(WorkoutExercise) then,
  ) = _$WorkoutExerciseCopyWithImpl<$Res, WorkoutExercise>;
  @useResult
  $Res call({
    String id,
    String name,
    ExerciseModality modality,
    String prescription,
    int targetSets,
    String? equipment,
    String? cue,
  });
}

/// @nodoc
class _$WorkoutExerciseCopyWithImpl<$Res, $Val extends WorkoutExercise>
    implements $WorkoutExerciseCopyWith<$Res> {
  _$WorkoutExerciseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkoutExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? modality = null,
    Object? prescription = null,
    Object? targetSets = null,
    Object? equipment = freezed,
    Object? cue = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            modality: null == modality
                ? _value.modality
                : modality // ignore: cast_nullable_to_non_nullable
                      as ExerciseModality,
            prescription: null == prescription
                ? _value.prescription
                : prescription // ignore: cast_nullable_to_non_nullable
                      as String,
            targetSets: null == targetSets
                ? _value.targetSets
                : targetSets // ignore: cast_nullable_to_non_nullable
                      as int,
            equipment: freezed == equipment
                ? _value.equipment
                : equipment // ignore: cast_nullable_to_non_nullable
                      as String?,
            cue: freezed == cue
                ? _value.cue
                : cue // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkoutExerciseImplCopyWith<$Res>
    implements $WorkoutExerciseCopyWith<$Res> {
  factory _$$WorkoutExerciseImplCopyWith(
    _$WorkoutExerciseImpl value,
    $Res Function(_$WorkoutExerciseImpl) then,
  ) = __$$WorkoutExerciseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    ExerciseModality modality,
    String prescription,
    int targetSets,
    String? equipment,
    String? cue,
  });
}

/// @nodoc
class __$$WorkoutExerciseImplCopyWithImpl<$Res>
    extends _$WorkoutExerciseCopyWithImpl<$Res, _$WorkoutExerciseImpl>
    implements _$$WorkoutExerciseImplCopyWith<$Res> {
  __$$WorkoutExerciseImplCopyWithImpl(
    _$WorkoutExerciseImpl _value,
    $Res Function(_$WorkoutExerciseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkoutExercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? modality = null,
    Object? prescription = null,
    Object? targetSets = null,
    Object? equipment = freezed,
    Object? cue = freezed,
  }) {
    return _then(
      _$WorkoutExerciseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        modality: null == modality
            ? _value.modality
            : modality // ignore: cast_nullable_to_non_nullable
                  as ExerciseModality,
        prescription: null == prescription
            ? _value.prescription
            : prescription // ignore: cast_nullable_to_non_nullable
                  as String,
        targetSets: null == targetSets
            ? _value.targetSets
            : targetSets // ignore: cast_nullable_to_non_nullable
                  as int,
        equipment: freezed == equipment
            ? _value.equipment
            : equipment // ignore: cast_nullable_to_non_nullable
                  as String?,
        cue: freezed == cue
            ? _value.cue
            : cue // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutExerciseImpl implements _WorkoutExercise {
  const _$WorkoutExerciseImpl({
    required this.id,
    required this.name,
    required this.modality,
    required this.prescription,
    this.targetSets = 1,
    this.equipment,
    this.cue,
  });

  factory _$WorkoutExerciseImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutExerciseImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final ExerciseModality modality;
  @override
  final String prescription;
  @override
  @JsonKey()
  final int targetSets;
  @override
  final String? equipment;
  @override
  final String? cue;

  @override
  String toString() {
    return 'WorkoutExercise(id: $id, name: $name, modality: $modality, prescription: $prescription, targetSets: $targetSets, equipment: $equipment, cue: $cue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutExerciseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.modality, modality) ||
                other.modality == modality) &&
            (identical(other.prescription, prescription) ||
                other.prescription == prescription) &&
            (identical(other.targetSets, targetSets) ||
                other.targetSets == targetSets) &&
            (identical(other.equipment, equipment) ||
                other.equipment == equipment) &&
            (identical(other.cue, cue) || other.cue == cue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    modality,
    prescription,
    targetSets,
    equipment,
    cue,
  );

  /// Create a copy of WorkoutExercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutExerciseImplCopyWith<_$WorkoutExerciseImpl> get copyWith =>
      __$$WorkoutExerciseImplCopyWithImpl<_$WorkoutExerciseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutExerciseImplToJson(this);
  }
}

abstract class _WorkoutExercise implements WorkoutExercise {
  const factory _WorkoutExercise({
    required final String id,
    required final String name,
    required final ExerciseModality modality,
    required final String prescription,
    final int targetSets,
    final String? equipment,
    final String? cue,
  }) = _$WorkoutExerciseImpl;

  factory _WorkoutExercise.fromJson(Map<String, dynamic> json) =
      _$WorkoutExerciseImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  ExerciseModality get modality;
  @override
  String get prescription;
  @override
  int get targetSets;
  @override
  String? get equipment;
  @override
  String? get cue;

  /// Create a copy of WorkoutExercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkoutExerciseImplCopyWith<_$WorkoutExerciseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
