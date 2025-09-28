// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_block.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WorkoutBlock _$WorkoutBlockFromJson(Map<String, dynamic> json) {
  return _WorkoutBlock.fromJson(json);
}

/// @nodoc
mixin _$WorkoutBlock {
  String get id => throw _privateConstructorUsedError;
  WorkoutBlockType get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  Duration get targetDuration => throw _privateConstructorUsedError;
  List<WorkoutExercise> get exercises => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Serializes this WorkoutBlock to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkoutBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkoutBlockCopyWith<WorkoutBlock> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutBlockCopyWith<$Res> {
  factory $WorkoutBlockCopyWith(
    WorkoutBlock value,
    $Res Function(WorkoutBlock) then,
  ) = _$WorkoutBlockCopyWithImpl<$Res, WorkoutBlock>;
  @useResult
  $Res call({
    String id,
    WorkoutBlockType type,
    String title,
    Duration targetDuration,
    List<WorkoutExercise> exercises,
    String description,
  });
}

/// @nodoc
class _$WorkoutBlockCopyWithImpl<$Res, $Val extends WorkoutBlock>
    implements $WorkoutBlockCopyWith<$Res> {
  _$WorkoutBlockCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkoutBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? targetDuration = null,
    Object? exercises = null,
    Object? description = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as WorkoutBlockType,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            targetDuration: null == targetDuration
                ? _value.targetDuration
                : targetDuration // ignore: cast_nullable_to_non_nullable
                      as Duration,
            exercises: null == exercises
                ? _value.exercises
                : exercises // ignore: cast_nullable_to_non_nullable
                      as List<WorkoutExercise>,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkoutBlockImplCopyWith<$Res>
    implements $WorkoutBlockCopyWith<$Res> {
  factory _$$WorkoutBlockImplCopyWith(
    _$WorkoutBlockImpl value,
    $Res Function(_$WorkoutBlockImpl) then,
  ) = __$$WorkoutBlockImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    WorkoutBlockType type,
    String title,
    Duration targetDuration,
    List<WorkoutExercise> exercises,
    String description,
  });
}

/// @nodoc
class __$$WorkoutBlockImplCopyWithImpl<$Res>
    extends _$WorkoutBlockCopyWithImpl<$Res, _$WorkoutBlockImpl>
    implements _$$WorkoutBlockImplCopyWith<$Res> {
  __$$WorkoutBlockImplCopyWithImpl(
    _$WorkoutBlockImpl _value,
    $Res Function(_$WorkoutBlockImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkoutBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? targetDuration = null,
    Object? exercises = null,
    Object? description = null,
  }) {
    return _then(
      _$WorkoutBlockImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as WorkoutBlockType,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        targetDuration: null == targetDuration
            ? _value.targetDuration
            : targetDuration // ignore: cast_nullable_to_non_nullable
                  as Duration,
        exercises: null == exercises
            ? _value._exercises
            : exercises // ignore: cast_nullable_to_non_nullable
                  as List<WorkoutExercise>,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutBlockImpl implements _WorkoutBlock {
  const _$WorkoutBlockImpl({
    required this.id,
    required this.type,
    required this.title,
    required this.targetDuration,
    required final List<WorkoutExercise> exercises,
    this.description = '',
  }) : _exercises = exercises;

  factory _$WorkoutBlockImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutBlockImplFromJson(json);

  @override
  final String id;
  @override
  final WorkoutBlockType type;
  @override
  final String title;
  @override
  final Duration targetDuration;
  final List<WorkoutExercise> _exercises;
  @override
  List<WorkoutExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  @override
  @JsonKey()
  final String description;

  @override
  String toString() {
    return 'WorkoutBlock(id: $id, type: $type, title: $title, targetDuration: $targetDuration, exercises: $exercises, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutBlockImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.targetDuration, targetDuration) ||
                other.targetDuration == targetDuration) &&
            const DeepCollectionEquality().equals(
              other._exercises,
              _exercises,
            ) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    title,
    targetDuration,
    const DeepCollectionEquality().hash(_exercises),
    description,
  );

  /// Create a copy of WorkoutBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutBlockImplCopyWith<_$WorkoutBlockImpl> get copyWith =>
      __$$WorkoutBlockImplCopyWithImpl<_$WorkoutBlockImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutBlockImplToJson(this);
  }
}

abstract class _WorkoutBlock implements WorkoutBlock {
  const factory _WorkoutBlock({
    required final String id,
    required final WorkoutBlockType type,
    required final String title,
    required final Duration targetDuration,
    required final List<WorkoutExercise> exercises,
    final String description,
  }) = _$WorkoutBlockImpl;

  factory _WorkoutBlock.fromJson(Map<String, dynamic> json) =
      _$WorkoutBlockImpl.fromJson;

  @override
  String get id;
  @override
  WorkoutBlockType get type;
  @override
  String get title;
  @override
  Duration get targetDuration;
  @override
  List<WorkoutExercise> get exercises;
  @override
  String get description;

  /// Create a copy of WorkoutBlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkoutBlockImplCopyWith<_$WorkoutBlockImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
