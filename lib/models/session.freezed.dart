// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SessionSetLog _$SessionSetLogFromJson(Map<String, dynamic> json) {
  return _SessionSetLog.fromJson(json);
}

/// @nodoc
mixin _$SessionSetLog {
  String get id => throw _privateConstructorUsedError;
  String get sessionBlockId => throw _privateConstructorUsedError;
  String get exerciseId => throw _privateConstructorUsedError;
  int get setIndex => throw _privateConstructorUsedError;
  double? get weightKg => throw _privateConstructorUsedError;
  int? get reps => throw _privateConstructorUsedError;
  @NullableDurationSecondsConverter()
  Duration? get duration => throw _privateConstructorUsedError;
  double? get rpe => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this SessionSetLog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionSetLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionSetLogCopyWith<SessionSetLog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionSetLogCopyWith<$Res> {
  factory $SessionSetLogCopyWith(
    SessionSetLog value,
    $Res Function(SessionSetLog) then,
  ) = _$SessionSetLogCopyWithImpl<$Res, SessionSetLog>;
  @useResult
  $Res call({
    String id,
    String sessionBlockId,
    String exerciseId,
    int setIndex,
    double? weightKg,
    int? reps,
    @NullableDurationSecondsConverter() Duration? duration,
    double? rpe,
    String? notes,
  });
}

/// @nodoc
class _$SessionSetLogCopyWithImpl<$Res, $Val extends SessionSetLog>
    implements $SessionSetLogCopyWith<$Res> {
  _$SessionSetLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionSetLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionBlockId = null,
    Object? exerciseId = null,
    Object? setIndex = null,
    Object? weightKg = freezed,
    Object? reps = freezed,
    Object? duration = freezed,
    Object? rpe = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionBlockId: null == sessionBlockId
                ? _value.sessionBlockId
                : sessionBlockId // ignore: cast_nullable_to_non_nullable
                      as String,
            exerciseId: null == exerciseId
                ? _value.exerciseId
                : exerciseId // ignore: cast_nullable_to_non_nullable
                      as String,
            setIndex: null == setIndex
                ? _value.setIndex
                : setIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            weightKg: freezed == weightKg
                ? _value.weightKg
                : weightKg // ignore: cast_nullable_to_non_nullable
                      as double?,
            reps: freezed == reps
                ? _value.reps
                : reps // ignore: cast_nullable_to_non_nullable
                      as int?,
            duration: freezed == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as Duration?,
            rpe: freezed == rpe
                ? _value.rpe
                : rpe // ignore: cast_nullable_to_non_nullable
                      as double?,
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
abstract class _$$SessionSetLogImplCopyWith<$Res>
    implements $SessionSetLogCopyWith<$Res> {
  factory _$$SessionSetLogImplCopyWith(
    _$SessionSetLogImpl value,
    $Res Function(_$SessionSetLogImpl) then,
  ) = __$$SessionSetLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sessionBlockId,
    String exerciseId,
    int setIndex,
    double? weightKg,
    int? reps,
    @NullableDurationSecondsConverter() Duration? duration,
    double? rpe,
    String? notes,
  });
}

/// @nodoc
class __$$SessionSetLogImplCopyWithImpl<$Res>
    extends _$SessionSetLogCopyWithImpl<$Res, _$SessionSetLogImpl>
    implements _$$SessionSetLogImplCopyWith<$Res> {
  __$$SessionSetLogImplCopyWithImpl(
    _$SessionSetLogImpl _value,
    $Res Function(_$SessionSetLogImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionSetLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionBlockId = null,
    Object? exerciseId = null,
    Object? setIndex = null,
    Object? weightKg = freezed,
    Object? reps = freezed,
    Object? duration = freezed,
    Object? rpe = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$SessionSetLogImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionBlockId: null == sessionBlockId
            ? _value.sessionBlockId
            : sessionBlockId // ignore: cast_nullable_to_non_nullable
                  as String,
        exerciseId: null == exerciseId
            ? _value.exerciseId
            : exerciseId // ignore: cast_nullable_to_non_nullable
                  as String,
        setIndex: null == setIndex
            ? _value.setIndex
            : setIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        weightKg: freezed == weightKg
            ? _value.weightKg
            : weightKg // ignore: cast_nullable_to_non_nullable
                  as double?,
        reps: freezed == reps
            ? _value.reps
            : reps // ignore: cast_nullable_to_non_nullable
                  as int?,
        duration: freezed == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as Duration?,
        rpe: freezed == rpe
            ? _value.rpe
            : rpe // ignore: cast_nullable_to_non_nullable
                  as double?,
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
class _$SessionSetLogImpl implements _SessionSetLog {
  const _$SessionSetLogImpl({
    required this.id,
    required this.sessionBlockId,
    required this.exerciseId,
    required this.setIndex,
    this.weightKg,
    this.reps,
    @NullableDurationSecondsConverter() this.duration,
    this.rpe,
    this.notes,
  });

  factory _$SessionSetLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionSetLogImplFromJson(json);

  @override
  final String id;
  @override
  final String sessionBlockId;
  @override
  final String exerciseId;
  @override
  final int setIndex;
  @override
  final double? weightKg;
  @override
  final int? reps;
  @override
  @NullableDurationSecondsConverter()
  final Duration? duration;
  @override
  final double? rpe;
  @override
  final String? notes;

  @override
  String toString() {
    return 'SessionSetLog(id: $id, sessionBlockId: $sessionBlockId, exerciseId: $exerciseId, setIndex: $setIndex, weightKg: $weightKg, reps: $reps, duration: $duration, rpe: $rpe, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionSetLogImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionBlockId, sessionBlockId) ||
                other.sessionBlockId == sessionBlockId) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.setIndex, setIndex) ||
                other.setIndex == setIndex) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.reps, reps) || other.reps == reps) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.rpe, rpe) || other.rpe == rpe) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sessionBlockId,
    exerciseId,
    setIndex,
    weightKg,
    reps,
    duration,
    rpe,
    notes,
  );

  /// Create a copy of SessionSetLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionSetLogImplCopyWith<_$SessionSetLogImpl> get copyWith =>
      __$$SessionSetLogImplCopyWithImpl<_$SessionSetLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionSetLogImplToJson(this);
  }
}

abstract class _SessionSetLog implements SessionSetLog {
  const factory _SessionSetLog({
    required final String id,
    required final String sessionBlockId,
    required final String exerciseId,
    required final int setIndex,
    final double? weightKg,
    final int? reps,
    @NullableDurationSecondsConverter() final Duration? duration,
    final double? rpe,
    final String? notes,
  }) = _$SessionSetLogImpl;

  factory _SessionSetLog.fromJson(Map<String, dynamic> json) =
      _$SessionSetLogImpl.fromJson;

  @override
  String get id;
  @override
  String get sessionBlockId;
  @override
  String get exerciseId;
  @override
  int get setIndex;
  @override
  double? get weightKg;
  @override
  int? get reps;
  @override
  @NullableDurationSecondsConverter()
  Duration? get duration;
  @override
  double? get rpe;
  @override
  String? get notes;

  /// Create a copy of SessionSetLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionSetLogImplCopyWith<_$SessionSetLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionBlock _$SessionBlockFromJson(Map<String, dynamic> json) {
  return _SessionBlock.fromJson(json);
}

/// @nodoc
mixin _$SessionBlock {
  String get id => throw _privateConstructorUsedError;
  String get sessionId => throw _privateConstructorUsedError;
  WorkoutBlockType get type => throw _privateConstructorUsedError;
  int get blockIndex => throw _privateConstructorUsedError;
  List<WorkoutExercise> get exercises => throw _privateConstructorUsedError;
  List<SessionSetLog> get logs => throw _privateConstructorUsedError;
  @DurationSecondsConverter()
  Duration get targetDuration => throw _privateConstructorUsedError;
  @NullableDurationSecondsConverter()
  Duration? get actualDuration => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this SessionBlock to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionBlockCopyWith<SessionBlock> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionBlockCopyWith<$Res> {
  factory $SessionBlockCopyWith(
    SessionBlock value,
    $Res Function(SessionBlock) then,
  ) = _$SessionBlockCopyWithImpl<$Res, SessionBlock>;
  @useResult
  $Res call({
    String id,
    String sessionId,
    WorkoutBlockType type,
    int blockIndex,
    List<WorkoutExercise> exercises,
    List<SessionSetLog> logs,
    @DurationSecondsConverter() Duration targetDuration,
    @NullableDurationSecondsConverter() Duration? actualDuration,
    String? notes,
  });
}

/// @nodoc
class _$SessionBlockCopyWithImpl<$Res, $Val extends SessionBlock>
    implements $SessionBlockCopyWith<$Res> {
  _$SessionBlockCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? type = null,
    Object? blockIndex = null,
    Object? exercises = null,
    Object? logs = null,
    Object? targetDuration = null,
    Object? actualDuration = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as WorkoutBlockType,
            blockIndex: null == blockIndex
                ? _value.blockIndex
                : blockIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            exercises: null == exercises
                ? _value.exercises
                : exercises // ignore: cast_nullable_to_non_nullable
                      as List<WorkoutExercise>,
            logs: null == logs
                ? _value.logs
                : logs // ignore: cast_nullable_to_non_nullable
                      as List<SessionSetLog>,
            targetDuration: null == targetDuration
                ? _value.targetDuration
                : targetDuration // ignore: cast_nullable_to_non_nullable
                      as Duration,
            actualDuration: freezed == actualDuration
                ? _value.actualDuration
                : actualDuration // ignore: cast_nullable_to_non_nullable
                      as Duration?,
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
abstract class _$$SessionBlockImplCopyWith<$Res>
    implements $SessionBlockCopyWith<$Res> {
  factory _$$SessionBlockImplCopyWith(
    _$SessionBlockImpl value,
    $Res Function(_$SessionBlockImpl) then,
  ) = __$$SessionBlockImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sessionId,
    WorkoutBlockType type,
    int blockIndex,
    List<WorkoutExercise> exercises,
    List<SessionSetLog> logs,
    @DurationSecondsConverter() Duration targetDuration,
    @NullableDurationSecondsConverter() Duration? actualDuration,
    String? notes,
  });
}

/// @nodoc
class __$$SessionBlockImplCopyWithImpl<$Res>
    extends _$SessionBlockCopyWithImpl<$Res, _$SessionBlockImpl>
    implements _$$SessionBlockImplCopyWith<$Res> {
  __$$SessionBlockImplCopyWithImpl(
    _$SessionBlockImpl _value,
    $Res Function(_$SessionBlockImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? type = null,
    Object? blockIndex = null,
    Object? exercises = null,
    Object? logs = null,
    Object? targetDuration = null,
    Object? actualDuration = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$SessionBlockImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as WorkoutBlockType,
        blockIndex: null == blockIndex
            ? _value.blockIndex
            : blockIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        exercises: null == exercises
            ? _value._exercises
            : exercises // ignore: cast_nullable_to_non_nullable
                  as List<WorkoutExercise>,
        logs: null == logs
            ? _value._logs
            : logs // ignore: cast_nullable_to_non_nullable
                  as List<SessionSetLog>,
        targetDuration: null == targetDuration
            ? _value.targetDuration
            : targetDuration // ignore: cast_nullable_to_non_nullable
                  as Duration,
        actualDuration: freezed == actualDuration
            ? _value.actualDuration
            : actualDuration // ignore: cast_nullable_to_non_nullable
                  as Duration?,
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
class _$SessionBlockImpl implements _SessionBlock {
  const _$SessionBlockImpl({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.blockIndex,
    required final List<WorkoutExercise> exercises,
    required final List<SessionSetLog> logs,
    @DurationSecondsConverter() required this.targetDuration,
    @NullableDurationSecondsConverter() this.actualDuration,
    this.notes,
  }) : _exercises = exercises,
       _logs = logs;

  factory _$SessionBlockImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionBlockImplFromJson(json);

  @override
  final String id;
  @override
  final String sessionId;
  @override
  final WorkoutBlockType type;
  @override
  final int blockIndex;
  final List<WorkoutExercise> _exercises;
  @override
  List<WorkoutExercise> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  final List<SessionSetLog> _logs;
  @override
  List<SessionSetLog> get logs {
    if (_logs is EqualUnmodifiableListView) return _logs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logs);
  }

  @override
  @DurationSecondsConverter()
  final Duration targetDuration;
  @override
  @NullableDurationSecondsConverter()
  final Duration? actualDuration;
  @override
  final String? notes;

  @override
  String toString() {
    return 'SessionBlock(id: $id, sessionId: $sessionId, type: $type, blockIndex: $blockIndex, exercises: $exercises, logs: $logs, targetDuration: $targetDuration, actualDuration: $actualDuration, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionBlockImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.blockIndex, blockIndex) ||
                other.blockIndex == blockIndex) &&
            const DeepCollectionEquality().equals(
              other._exercises,
              _exercises,
            ) &&
            const DeepCollectionEquality().equals(other._logs, _logs) &&
            (identical(other.targetDuration, targetDuration) ||
                other.targetDuration == targetDuration) &&
            (identical(other.actualDuration, actualDuration) ||
                other.actualDuration == actualDuration) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sessionId,
    type,
    blockIndex,
    const DeepCollectionEquality().hash(_exercises),
    const DeepCollectionEquality().hash(_logs),
    targetDuration,
    actualDuration,
    notes,
  );

  /// Create a copy of SessionBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionBlockImplCopyWith<_$SessionBlockImpl> get copyWith =>
      __$$SessionBlockImplCopyWithImpl<_$SessionBlockImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionBlockImplToJson(this);
  }
}

abstract class _SessionBlock implements SessionBlock {
  const factory _SessionBlock({
    required final String id,
    required final String sessionId,
    required final WorkoutBlockType type,
    required final int blockIndex,
    required final List<WorkoutExercise> exercises,
    required final List<SessionSetLog> logs,
    @DurationSecondsConverter() required final Duration targetDuration,
    @NullableDurationSecondsConverter() final Duration? actualDuration,
    final String? notes,
  }) = _$SessionBlockImpl;

  factory _SessionBlock.fromJson(Map<String, dynamic> json) =
      _$SessionBlockImpl.fromJson;

  @override
  String get id;
  @override
  String get sessionId;
  @override
  WorkoutBlockType get type;
  @override
  int get blockIndex;
  @override
  List<WorkoutExercise> get exercises;
  @override
  List<SessionSetLog> get logs;
  @override
  @DurationSecondsConverter()
  Duration get targetDuration;
  @override
  @NullableDurationSecondsConverter()
  Duration? get actualDuration;
  @override
  String? get notes;

  /// Create a copy of SessionBlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionBlockImplCopyWith<_$SessionBlockImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BreathSegment _$BreathSegmentFromJson(Map<String, dynamic> json) {
  return _BreathSegment.fromJson(json);
}

/// @nodoc
mixin _$BreathSegment {
  String get id => throw _privateConstructorUsedError;
  String get sessionId => throw _privateConstructorUsedError;
  String get pattern => throw _privateConstructorUsedError;
  @DurationSecondsConverter()
  Duration get targetDuration => throw _privateConstructorUsedError;
  @NullableDurationSecondsConverter()
  Duration? get actualDuration => throw _privateConstructorUsedError;

  /// Serializes this BreathSegment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BreathSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BreathSegmentCopyWith<BreathSegment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BreathSegmentCopyWith<$Res> {
  factory $BreathSegmentCopyWith(
    BreathSegment value,
    $Res Function(BreathSegment) then,
  ) = _$BreathSegmentCopyWithImpl<$Res, BreathSegment>;
  @useResult
  $Res call({
    String id,
    String sessionId,
    String pattern,
    @DurationSecondsConverter() Duration targetDuration,
    @NullableDurationSecondsConverter() Duration? actualDuration,
  });
}

/// @nodoc
class _$BreathSegmentCopyWithImpl<$Res, $Val extends BreathSegment>
    implements $BreathSegmentCopyWith<$Res> {
  _$BreathSegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BreathSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? pattern = null,
    Object? targetDuration = null,
    Object? actualDuration = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            pattern: null == pattern
                ? _value.pattern
                : pattern // ignore: cast_nullable_to_non_nullable
                      as String,
            targetDuration: null == targetDuration
                ? _value.targetDuration
                : targetDuration // ignore: cast_nullable_to_non_nullable
                      as Duration,
            actualDuration: freezed == actualDuration
                ? _value.actualDuration
                : actualDuration // ignore: cast_nullable_to_non_nullable
                      as Duration?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BreathSegmentImplCopyWith<$Res>
    implements $BreathSegmentCopyWith<$Res> {
  factory _$$BreathSegmentImplCopyWith(
    _$BreathSegmentImpl value,
    $Res Function(_$BreathSegmentImpl) then,
  ) = __$$BreathSegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sessionId,
    String pattern,
    @DurationSecondsConverter() Duration targetDuration,
    @NullableDurationSecondsConverter() Duration? actualDuration,
  });
}

/// @nodoc
class __$$BreathSegmentImplCopyWithImpl<$Res>
    extends _$BreathSegmentCopyWithImpl<$Res, _$BreathSegmentImpl>
    implements _$$BreathSegmentImplCopyWith<$Res> {
  __$$BreathSegmentImplCopyWithImpl(
    _$BreathSegmentImpl _value,
    $Res Function(_$BreathSegmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BreathSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? pattern = null,
    Object? targetDuration = null,
    Object? actualDuration = freezed,
  }) {
    return _then(
      _$BreathSegmentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        pattern: null == pattern
            ? _value.pattern
            : pattern // ignore: cast_nullable_to_non_nullable
                  as String,
        targetDuration: null == targetDuration
            ? _value.targetDuration
            : targetDuration // ignore: cast_nullable_to_non_nullable
                  as Duration,
        actualDuration: freezed == actualDuration
            ? _value.actualDuration
            : actualDuration // ignore: cast_nullable_to_non_nullable
                  as Duration?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BreathSegmentImpl implements _BreathSegment {
  const _$BreathSegmentImpl({
    required this.id,
    required this.sessionId,
    required this.pattern,
    @DurationSecondsConverter() required this.targetDuration,
    @NullableDurationSecondsConverter() this.actualDuration,
  });

  factory _$BreathSegmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$BreathSegmentImplFromJson(json);

  @override
  final String id;
  @override
  final String sessionId;
  @override
  final String pattern;
  @override
  @DurationSecondsConverter()
  final Duration targetDuration;
  @override
  @NullableDurationSecondsConverter()
  final Duration? actualDuration;

  @override
  String toString() {
    return 'BreathSegment(id: $id, sessionId: $sessionId, pattern: $pattern, targetDuration: $targetDuration, actualDuration: $actualDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BreathSegmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.targetDuration, targetDuration) ||
                other.targetDuration == targetDuration) &&
            (identical(other.actualDuration, actualDuration) ||
                other.actualDuration == actualDuration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sessionId,
    pattern,
    targetDuration,
    actualDuration,
  );

  /// Create a copy of BreathSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BreathSegmentImplCopyWith<_$BreathSegmentImpl> get copyWith =>
      __$$BreathSegmentImplCopyWithImpl<_$BreathSegmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BreathSegmentImplToJson(this);
  }
}

abstract class _BreathSegment implements BreathSegment {
  const factory _BreathSegment({
    required final String id,
    required final String sessionId,
    required final String pattern,
    @DurationSecondsConverter() required final Duration targetDuration,
    @NullableDurationSecondsConverter() final Duration? actualDuration,
  }) = _$BreathSegmentImpl;

  factory _BreathSegment.fromJson(Map<String, dynamic> json) =
      _$BreathSegmentImpl.fromJson;

  @override
  String get id;
  @override
  String get sessionId;
  @override
  String get pattern;
  @override
  @DurationSecondsConverter()
  Duration get targetDuration;
  @override
  @NullableDurationSecondsConverter()
  Duration? get actualDuration;

  /// Create a copy of BreathSegment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BreathSegmentImplCopyWith<_$BreathSegmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Session _$SessionFromJson(Map<String, dynamic> json) {
  return _Session.fromJson(json);
}

/// @nodoc
mixin _$Session {
  String get id => throw _privateConstructorUsedError;
  String get templateId => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @NullableDurationSecondsConverter()
  Duration? get duration => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String? get feeling => throw _privateConstructorUsedError;
  List<SessionBlock> get blocks => throw _privateConstructorUsedError;
  List<BreathSegment> get breathSegments => throw _privateConstructorUsedError;
  bool get isPaused => throw _privateConstructorUsedError;
  DateTime? get pausedAt => throw _privateConstructorUsedError;
  @DurationSecondsConverter()
  Duration get totalPausedDuration => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCopyWith<Session> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCopyWith<$Res> {
  factory $SessionCopyWith(Session value, $Res Function(Session) then) =
      _$SessionCopyWithImpl<$Res, Session>;
  @useResult
  $Res call({
    String id,
    String templateId,
    DateTime startedAt,
    DateTime? completedAt,
    @NullableDurationSecondsConverter() Duration? duration,
    String? notes,
    String? feeling,
    List<SessionBlock> blocks,
    List<BreathSegment> breathSegments,
    bool isPaused,
    DateTime? pausedAt,
    @DurationSecondsConverter() Duration totalPausedDuration,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$SessionCopyWithImpl<$Res, $Val extends Session>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? templateId = null,
    Object? startedAt = null,
    Object? completedAt = freezed,
    Object? duration = freezed,
    Object? notes = freezed,
    Object? feeling = freezed,
    Object? blocks = null,
    Object? breathSegments = null,
    Object? isPaused = null,
    Object? pausedAt = freezed,
    Object? totalPausedDuration = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            templateId: null == templateId
                ? _value.templateId
                : templateId // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            duration: freezed == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as Duration?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            feeling: freezed == feeling
                ? _value.feeling
                : feeling // ignore: cast_nullable_to_non_nullable
                      as String?,
            blocks: null == blocks
                ? _value.blocks
                : blocks // ignore: cast_nullable_to_non_nullable
                      as List<SessionBlock>,
            breathSegments: null == breathSegments
                ? _value.breathSegments
                : breathSegments // ignore: cast_nullable_to_non_nullable
                      as List<BreathSegment>,
            isPaused: null == isPaused
                ? _value.isPaused
                : isPaused // ignore: cast_nullable_to_non_nullable
                      as bool,
            pausedAt: freezed == pausedAt
                ? _value.pausedAt
                : pausedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            totalPausedDuration: null == totalPausedDuration
                ? _value.totalPausedDuration
                : totalPausedDuration // ignore: cast_nullable_to_non_nullable
                      as Duration,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionImplCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$$SessionImplCopyWith(
    _$SessionImpl value,
    $Res Function(_$SessionImpl) then,
  ) = __$$SessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String templateId,
    DateTime startedAt,
    DateTime? completedAt,
    @NullableDurationSecondsConverter() Duration? duration,
    String? notes,
    String? feeling,
    List<SessionBlock> blocks,
    List<BreathSegment> breathSegments,
    bool isPaused,
    DateTime? pausedAt,
    @DurationSecondsConverter() Duration totalPausedDuration,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$SessionImplCopyWithImpl<$Res>
    extends _$SessionCopyWithImpl<$Res, _$SessionImpl>
    implements _$$SessionImplCopyWith<$Res> {
  __$$SessionImplCopyWithImpl(
    _$SessionImpl _value,
    $Res Function(_$SessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? templateId = null,
    Object? startedAt = null,
    Object? completedAt = freezed,
    Object? duration = freezed,
    Object? notes = freezed,
    Object? feeling = freezed,
    Object? blocks = null,
    Object? breathSegments = null,
    Object? isPaused = null,
    Object? pausedAt = freezed,
    Object? totalPausedDuration = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$SessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        templateId: null == templateId
            ? _value.templateId
            : templateId // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        duration: freezed == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as Duration?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        feeling: freezed == feeling
            ? _value.feeling
            : feeling // ignore: cast_nullable_to_non_nullable
                  as String?,
        blocks: null == blocks
            ? _value._blocks
            : blocks // ignore: cast_nullable_to_non_nullable
                  as List<SessionBlock>,
        breathSegments: null == breathSegments
            ? _value._breathSegments
            : breathSegments // ignore: cast_nullable_to_non_nullable
                  as List<BreathSegment>,
        isPaused: null == isPaused
            ? _value.isPaused
            : isPaused // ignore: cast_nullable_to_non_nullable
                  as bool,
        pausedAt: freezed == pausedAt
            ? _value.pausedAt
            : pausedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        totalPausedDuration: null == totalPausedDuration
            ? _value.totalPausedDuration
            : totalPausedDuration // ignore: cast_nullable_to_non_nullable
                  as Duration,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionImpl implements _Session {
  const _$SessionImpl({
    required this.id,
    required this.templateId,
    required this.startedAt,
    this.completedAt,
    @NullableDurationSecondsConverter() this.duration,
    this.notes,
    this.feeling,
    required final List<SessionBlock> blocks,
    required final List<BreathSegment> breathSegments,
    this.isPaused = false,
    this.pausedAt,
    @DurationSecondsConverter() this.totalPausedDuration = Duration.zero,
    this.updatedAt,
  }) : _blocks = blocks,
       _breathSegments = breathSegments;

  factory _$SessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionImplFromJson(json);

  @override
  final String id;
  @override
  final String templateId;
  @override
  final DateTime startedAt;
  @override
  final DateTime? completedAt;
  @override
  @NullableDurationSecondsConverter()
  final Duration? duration;
  @override
  final String? notes;
  @override
  final String? feeling;
  final List<SessionBlock> _blocks;
  @override
  List<SessionBlock> get blocks {
    if (_blocks is EqualUnmodifiableListView) return _blocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blocks);
  }

  final List<BreathSegment> _breathSegments;
  @override
  List<BreathSegment> get breathSegments {
    if (_breathSegments is EqualUnmodifiableListView) return _breathSegments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_breathSegments);
  }

  @override
  @JsonKey()
  final bool isPaused;
  @override
  final DateTime? pausedAt;
  @override
  @JsonKey()
  @DurationSecondsConverter()
  final Duration totalPausedDuration;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Session(id: $id, templateId: $templateId, startedAt: $startedAt, completedAt: $completedAt, duration: $duration, notes: $notes, feeling: $feeling, blocks: $blocks, breathSegments: $breathSegments, isPaused: $isPaused, pausedAt: $pausedAt, totalPausedDuration: $totalPausedDuration, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.templateId, templateId) ||
                other.templateId == templateId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.feeling, feeling) || other.feeling == feeling) &&
            const DeepCollectionEquality().equals(other._blocks, _blocks) &&
            const DeepCollectionEquality().equals(
              other._breathSegments,
              _breathSegments,
            ) &&
            (identical(other.isPaused, isPaused) ||
                other.isPaused == isPaused) &&
            (identical(other.pausedAt, pausedAt) ||
                other.pausedAt == pausedAt) &&
            (identical(other.totalPausedDuration, totalPausedDuration) ||
                other.totalPausedDuration == totalPausedDuration) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    templateId,
    startedAt,
    completedAt,
    duration,
    notes,
    feeling,
    const DeepCollectionEquality().hash(_blocks),
    const DeepCollectionEquality().hash(_breathSegments),
    isPaused,
    pausedAt,
    totalPausedDuration,
    updatedAt,
  );

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionImplCopyWith<_$SessionImpl> get copyWith =>
      __$$SessionImplCopyWithImpl<_$SessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionImplToJson(this);
  }
}

abstract class _Session implements Session {
  const factory _Session({
    required final String id,
    required final String templateId,
    required final DateTime startedAt,
    final DateTime? completedAt,
    @NullableDurationSecondsConverter() final Duration? duration,
    final String? notes,
    final String? feeling,
    required final List<SessionBlock> blocks,
    required final List<BreathSegment> breathSegments,
    final bool isPaused,
    final DateTime? pausedAt,
    @DurationSecondsConverter() final Duration totalPausedDuration,
    final DateTime? updatedAt,
  }) = _$SessionImpl;

  factory _Session.fromJson(Map<String, dynamic> json) = _$SessionImpl.fromJson;

  @override
  String get id;
  @override
  String get templateId;
  @override
  DateTime get startedAt;
  @override
  DateTime? get completedAt;
  @override
  @NullableDurationSecondsConverter()
  Duration? get duration;
  @override
  String? get notes;
  @override
  String? get feeling;
  @override
  List<SessionBlock> get blocks;
  @override
  List<BreathSegment> get breathSegments;
  @override
  bool get isPaused;
  @override
  DateTime? get pausedAt;
  @override
  @DurationSecondsConverter()
  Duration get totalPausedDuration;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionImplCopyWith<_$SessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
