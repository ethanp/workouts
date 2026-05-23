// ignore_for_file: invalid_annotation_target

import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/exercise_set_metrics.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/utils/json_converters.dart';
import 'package:workouts/utils/weight_display.dart';

part 'workout_exercise.freezed.dart';
part 'workout_exercise.g.dart';

enum ExerciseModality { reps, timed, hold, mobility, breath }

enum PlannedSetType { warmup, working }

@freezed
abstract class PlannedSet with _$PlannedSet {
  const factory PlannedSet({
    @Default(PlannedSetType.working) PlannedSetType type,
    int? reps,
    @JsonKey(name: 'weightKg')
    @NullableWeightKilogramsConverter()
    Weight? weight,
    @JsonKey(name: 'durationSeconds')
    @NullableDurationSecondsConverter()
    Duration? duration,
    int? unitRemaining,
    String? targetIntensity,
    String? note,
  }) = _PlannedSet;

  const PlannedSet._();

  factory PlannedSet.fromJson(Map<String, dynamic> json) =>
      _$PlannedSetFromJson(json);

  /// Builds a fresh warmup-typed planned set, suitable for inserting at the
  /// head of an exercise's unlogged tail.
  ///
  /// Priority: copy [sibling] when given (so a 2nd/3rd warmup mirrors the
  /// first); else inherit cadence (reps/duration/unitRemaining) from the
  /// first working set in [exercise] but leave weight + targetIntensity
  /// null (warmups stay unprescribed for load and effort); else fall back
  /// to a modality-appropriate default.
  factory PlannedSet.newWarmup({
    required WorkoutExercise exercise,
    PlannedSet? sibling,
  }) {
    if (sibling != null) {
      return sibling.copyWith(type: PlannedSetType.warmup);
    }
    final firstWorkingSet = exercise.plannedSets
        .where((plannedSet) => plannedSet.type == PlannedSetType.working)
        .firstOrNull;
    if (firstWorkingSet != null) {
      return PlannedSet(
        type: PlannedSetType.warmup,
        reps: firstWorkingSet.reps,
        duration: firstWorkingSet.duration,
        unitRemaining: firstWorkingSet.unitRemaining,
      );
    }
    return PlannedSet(
      type: PlannedSetType.warmup,
      reps: exercise.setMetrics.tracksReps ? 8 : null,
      duration: exercise.setMetrics.tracksDuration
          ? (exercise.workDuration ?? const Duration(seconds: 30))
          : null,
    );
  }

  static List<PlannedSet> listFromJsonString(String? plannedSetsJson) {
    if (plannedSetsJson == null || plannedSetsJson.isEmpty) {
      return const [];
    }
    final plannedSetValues = _decodePlannedSetValues(plannedSetsJson);
    return plannedSetValues
        .map(
          (plannedSetValue) =>
              PlannedSet.fromJson(_plannedSetJsonMap(plannedSetValue)),
        )
        .toList();
  }

  static List<dynamic> _decodePlannedSetValues(String plannedSetsJson) {
    final decoded = jsonDecode(plannedSetsJson);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is String && decoded.isNotEmpty) {
      final doubleDecoded = jsonDecode(decoded);
      if (doubleDecoded is List<dynamic>) return doubleDecoded;
    }
    throw const FormatException('planned_sets must decode to a list');
  }

  static Map<String, dynamic> _plannedSetJsonMap(Object? plannedSetValue) {
    if (plannedSetValue is Map<String, dynamic>) return plannedSetValue;
    if (plannedSetValue is Map) {
      return Map<String, dynamic>.from(plannedSetValue);
    }
    if (plannedSetValue is String && plannedSetValue.isNotEmpty) {
      final decoded = jsonDecode(plannedSetValue);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('planned set entry must decode to a map');
  }

  static String listToJsonString(List<PlannedSet> plannedSets) =>
      jsonEncode(plannedSets.map((plannedSet) => plannedSet.toJson()).toList());
}

@freezed
abstract class WorkoutExercise with _$WorkoutExercise {
  const factory WorkoutExercise({
    required String id,
    required String name,
    required ExerciseModality modality,
    required String prescription,
    @Default(1) int targetSets,
    String? equipment,
    @Default([]) List<String> cues,
    @NullableDurationSecondsConverter() Duration? setupDuration,
    @NullableDurationSecondsConverter() Duration? workDuration,
    @NullableDurationSecondsConverter() Duration? restDuration,
    @Default([]) List<ExerciseBenefit> benefits,
    @Default([]) List<PlannedSet> plannedSets,
    @Default(ExerciseSetMetricsStyle.repsOnly)
    ExerciseSetMetricsStyle setMetricsStyle,
    @Default(false) bool isUnilateral,
  }) = _WorkoutExercise;

  const WorkoutExercise._();

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      _$WorkoutExerciseFromJson(json);

  /// Number of times each planned set is performed before advancing to the
  /// next planned set definition. Bilateral exercises perform a planned set
  /// once; unilateral exercises (split squat, single-leg work, single-arm
  /// rows) perform it twice — once per side. Side identity isn't tracked.
  int get sidesPerSet => isUnilateral ? 2 : 1;

  int get effectiveTargetSets {
    final base = plannedSets.isNotEmpty ? plannedSets.length : targetSets;
    return base * sidesPerSet;
  }

  int get warmupSetCount => plannedSets
      .where((plannedSet) => plannedSet.type == PlannedSetType.warmup)
      .length;

  int get workingSetCount => plannedSets
      .where((plannedSet) => plannedSet.type == PlannedSetType.working)
      .length;

  String get prescriptionLabel {
    if (plannedSets.isEmpty) return prescription;
    return plannedSetsPrescriptionLabel(plannedSets, this);
  }

  ExerciseSetMetrics get setMetrics => ExerciseSetMetrics(setMetricsStyle);

  bool get supportsAddedWeight => setMetrics.supportsAddedWeight;
}

ExerciseSetMetricsStyle inferSetMetricsStyle({
  required ExerciseModality modality,
  required List<PlannedSet> plannedSets,
}) {
  final hasWeightedSet = plannedSets.any(
    (plannedSet) => plannedSet.weight != null,
  );
  if (hasWeightedSet) return ExerciseSetMetricsStyle.repsAndWeight;

  final hasReps = plannedSets.any((plannedSet) => plannedSet.reps != null);
  final hasDuration = plannedSets.any(
    (plannedSet) => plannedSet.duration != null,
  );
  if (hasReps && hasDuration) return ExerciseSetMetricsStyle.repsAndDuration;
  if (hasDuration) return ExerciseSetMetricsStyle.durationOnly;
  if (hasReps) return ExerciseSetMetricsStyle.repsOnly;

  return switch (modality) {
    ExerciseModality.timed ||
    ExerciseModality.hold => ExerciseSetMetricsStyle.durationOnly,
    ExerciseModality.mobility ||
    ExerciseModality.breath => ExerciseSetMetricsStyle.repsAndDuration,
    ExerciseModality.reps => ExerciseSetMetricsStyle.repsOnly,
  };
}

String plannedSetsPrescriptionLabel(
  List<PlannedSet> plannedSets,
  WorkoutExercise exercise,
) => _PlannedSetLabelFormatter(plannedSets, exercise).label;

List<PlannedSet> plannedSetsFromLegacyPrescription({
  required ExerciseModality modality,
  required String prescription,
  required int targetSets,
}) {
  if (targetSets <= 0) return const [];

  final reps = _legacyPrescriptionReps(prescription);
  final duration = _legacyPrescriptionDuration(prescription);

  return [
    for (var setIndex = 0; setIndex < targetSets; setIndex++)
      PlannedSet(
        reps: _usesReps(modality) ? reps : null,
        duration: _usesDuration(modality) ? duration : null,
      ),
  ];
}

bool _usesReps(ExerciseModality modality) {
  return modality == ExerciseModality.reps ||
      modality == ExerciseModality.mobility ||
      modality == ExerciseModality.breath;
}

bool _usesDuration(ExerciseModality modality) {
  return modality == ExerciseModality.timed ||
      modality == ExerciseModality.hold ||
      modality == ExerciseModality.mobility ||
      modality == ExerciseModality.breath;
}

int? _legacyPrescriptionReps(String prescription) {
  final afterSetsMatch = RegExp(
    r'^\s*\d+\s*[×x]\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(prescription);
  if (afterSetsMatch != null) return int.parse(afterSetsMatch.group(1)!);

  final numberMatch = RegExp(r'(\d+)').firstMatch(prescription);
  if (numberMatch == null) return null;
  return int.parse(numberMatch.group(1)!);
}

Duration? _legacyPrescriptionDuration(String prescription) {
  final secondsMatch = RegExp(
    r'(\d+)\s*(?:s|sec|secs|second|seconds)\b',
    caseSensitive: false,
  ).firstMatch(prescription);
  if (secondsMatch != null) {
    return Duration(seconds: int.parse(secondsMatch.group(1)!));
  }

  final minutesMatch = RegExp(
    r'(\d+)\s*(?:m|min|mins|minute|minutes)\b',
    caseSensitive: false,
  ).firstMatch(prescription);
  if (minutesMatch != null) {
    return Duration(minutes: int.parse(minutesMatch.group(1)!));
  }

  return null;
}

class _PlannedSetLabelFormatter {
  const _PlannedSetLabelFormatter(this.plannedSets, this.exercise);

  final List<PlannedSet> plannedSets;
  final WorkoutExercise exercise;

  String get label {
    final base = _baseLabel();
    if (exercise.isUnilateral) return '$base each side';
    return base;
  }

  String _baseLabel() {
    final groupedLabels = <String>[];
    final warmupCount = plannedSets
        .where((plannedSet) => plannedSet.type == PlannedSetType.warmup)
        .length;
    if (warmupCount > 0) groupedLabels.add('$warmupCount warmup');

    final workingSets = plannedSets
        .where((plannedSet) => plannedSet.type == PlannedSetType.working)
        .toList();
    if (workingSets.isNotEmpty) {
      groupedLabels.add(_workingSetsLabel(workingSets));
    }

    if (groupedLabels.isEmpty) return '${plannedSets.length} sets';
    return groupedLabels.join(' + ');
  }

  String _workingSetsLabel(List<PlannedSet> workingSets) {
    final firstWorkingSet = workingSets.first;
    final allSame = workingSets.every(
      (plannedSet) =>
          plannedSet.reps == firstWorkingSet.reps &&
          plannedSet.weight == firstWorkingSet.weight &&
          plannedSet.duration == firstWorkingSet.duration &&
          plannedSet.targetIntensity == firstWorkingSet.targetIntensity,
    );
    if (!allSame) return '${workingSets.length} working';

    final targetLabel = _targetLabel(firstWorkingSet);
    if (targetLabel.isEmpty) return '${workingSets.length} working';
    return '${workingSets.length} x $targetLabel';
  }

  String _targetLabel(PlannedSet plannedSet) {
    final base = _baseTargetLabel(plannedSet);
    if (base.isEmpty) return '';
    final intensity = plannedSet.targetIntensity;
    if (intensity == null || intensity.isEmpty) return base;
    return '$base, $intensity';
  }

  String _baseTargetLabel(PlannedSet plannedSet) {
    if (plannedSet.reps != null && plannedSet.weight != null) {
      return '${plannedSet.reps} @ ${plannedSet.weight!.formatFor(exercise)}';
    }
    if (plannedSet.reps != null) return '${plannedSet.reps} reps';
    if (plannedSet.duration != null) {
      return '${plannedSet.duration!.inSeconds}s';
    }
    return '';
  }
}
