// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WorkoutTemplate _$WorkoutTemplateFromJson(Map<String, dynamic> json) {
  return _WorkoutTemplate.fromJson(json);
}

/// @nodoc
mixin _$WorkoutTemplate {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get goal => throw _privateConstructorUsedError;
  List<WorkoutBlock> get blocks => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this WorkoutTemplate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkoutTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkoutTemplateCopyWith<WorkoutTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutTemplateCopyWith<$Res> {
  factory $WorkoutTemplateCopyWith(
    WorkoutTemplate value,
    $Res Function(WorkoutTemplate) then,
  ) = _$WorkoutTemplateCopyWithImpl<$Res, WorkoutTemplate>;
  @useResult
  $Res call({
    String id,
    String name,
    String goal,
    List<WorkoutBlock> blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
}

/// @nodoc
class _$WorkoutTemplateCopyWithImpl<$Res, $Val extends WorkoutTemplate>
    implements $WorkoutTemplateCopyWith<$Res> {
  _$WorkoutTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkoutTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? goal = null,
    Object? blocks = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? notes = freezed,
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
            goal: null == goal
                ? _value.goal
                : goal // ignore: cast_nullable_to_non_nullable
                      as String,
            blocks: null == blocks
                ? _value.blocks
                : blocks // ignore: cast_nullable_to_non_nullable
                      as List<WorkoutBlock>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkoutTemplateImplCopyWith<$Res>
    implements $WorkoutTemplateCopyWith<$Res> {
  factory _$$WorkoutTemplateImplCopyWith(
    _$WorkoutTemplateImpl value,
    $Res Function(_$WorkoutTemplateImpl) then,
  ) = __$$WorkoutTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String goal,
    List<WorkoutBlock> blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
}

/// @nodoc
class __$$WorkoutTemplateImplCopyWithImpl<$Res>
    extends _$WorkoutTemplateCopyWithImpl<$Res, _$WorkoutTemplateImpl>
    implements _$$WorkoutTemplateImplCopyWith<$Res> {
  __$$WorkoutTemplateImplCopyWithImpl(
    _$WorkoutTemplateImpl _value,
    $Res Function(_$WorkoutTemplateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WorkoutTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? goal = null,
    Object? blocks = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$WorkoutTemplateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        goal: null == goal
            ? _value.goal
            : goal // ignore: cast_nullable_to_non_nullable
                  as String,
        blocks: null == blocks
            ? _value._blocks
            : blocks // ignore: cast_nullable_to_non_nullable
                  as List<WorkoutBlock>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutTemplateImpl implements _WorkoutTemplate {
  const _$WorkoutTemplateImpl({
    required this.id,
    required this.name,
    required this.goal,
    required final List<WorkoutBlock> blocks,
    this.createdAt,
    this.updatedAt,
    this.notes,
  }) : _blocks = blocks;

  factory _$WorkoutTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String goal;
  final List<WorkoutBlock> _blocks;
  @override
  List<WorkoutBlock> get blocks {
    if (_blocks is EqualUnmodifiableListView) return _blocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blocks);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final String? notes;

  @override
  String toString() {
    return 'WorkoutTemplate(id: $id, name: $name, goal: $goal, blocks: $blocks, createdAt: $createdAt, updatedAt: $updatedAt, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            const DeepCollectionEquality().equals(other._blocks, _blocks) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    goal,
    const DeepCollectionEquality().hash(_blocks),
    createdAt,
    updatedAt,
    notes,
  );

  /// Create a copy of WorkoutTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutTemplateImplCopyWith<_$WorkoutTemplateImpl> get copyWith =>
      __$$WorkoutTemplateImplCopyWithImpl<_$WorkoutTemplateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutTemplateImplToJson(this);
  }
}

abstract class _WorkoutTemplate implements WorkoutTemplate {
  const factory _WorkoutTemplate({
    required final String id,
    required final String name,
    required final String goal,
    required final List<WorkoutBlock> blocks,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final String? notes,
  }) = _$WorkoutTemplateImpl;

  factory _WorkoutTemplate.fromJson(Map<String, dynamic> json) =
      _$WorkoutTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get goal;
  @override
  List<WorkoutBlock> get blocks;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  String? get notes;

  /// Create a copy of WorkoutTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkoutTemplateImplCopyWith<_$WorkoutTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
