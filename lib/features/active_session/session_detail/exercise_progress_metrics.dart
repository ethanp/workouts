import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/models/exercise_set_metrics.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/weight.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

/// One session's worth of progress for a single exercise: the heaviest /
/// best single set ([topSet]) and the cumulative work done ([volume]).
///
/// The numeric meaning of both fields depends on the exercise's set metrics
/// style: for weighted exercises they are weights/tonnage in display units
/// (lb or kg), for rep-based they are counts, for time-based they are
/// seconds. [ExerciseProgressMetrics] is the single source of truth for
/// that mapping.
class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.topSet,
    required this.volume,
  });

  final DateTime date;
  final double topSet;
  final double volume;
}

/// Pure logic that turns a list of [ExerciseHistoryEntry] into trend
/// points and formats their values for chart axes / legends. Auto-picks
/// the right notion of "top set" and "volume" from the exercise's set
/// metrics style so callers don't need to branch.
class ExerciseProgressMetrics {
  const ExerciseProgressMetrics(this.exercise);

  final WorkoutExercise exercise;

  ExerciseSetMetricsStyle get _style => exercise.setMetrics.style;

  /// One point per [entries] item, sorted oldest-first so the trend chart
  /// renders left-to-right chronologically. Entries that produced no
  /// meaningful values (e.g. a weighted exercise where every set lacked
  /// weight) are dropped.
  List<ExerciseProgressPoint> pointsFromHistory(
    List<ExerciseHistoryEntry> entries,
  ) {
    final points = <ExerciseProgressPoint>[];
    for (final entry in entries) {
      final point = _pointForEntry(entry);
      if (point != null) points.add(point);
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  ExerciseProgressPoint? _pointForEntry(ExerciseHistoryEntry entry) {
    final topSet = _topSetValue(entry.sets);
    final volume = _volumeValue(entry.sets);
    if (topSet == null && volume == null) return null;
    return ExerciseProgressPoint(
      date: entry.completedAt,
      topSet: topSet ?? 0,
      volume: volume ?? 0,
    );
  }

  String formatTopSet(double value) => switch (_style) {
    ExerciseSetMetricsStyle.repsAndWeight => _formatWeight(value),
    ExerciseSetMetricsStyle.repsOnly ||
    ExerciseSetMetricsStyle.repsAndDuration => '${value.round()} reps',
    ExerciseSetMetricsStyle.durationOnly => _formatSeconds(value),
  };

  String formatVolume(double value) => switch (_style) {
    ExerciseSetMetricsStyle.repsAndWeight => _formatWeight(value),
    ExerciseSetMetricsStyle.repsOnly ||
    ExerciseSetMetricsStyle.repsAndDuration => '${value.round()} reps',
    ExerciseSetMetricsStyle.durationOnly => _formatSeconds(value),
  };

  double? _topSetValue(List<SessionSetLog> logs) {
    return switch (_style) {
      ExerciseSetMetricsStyle.repsAndWeight => _maxWeightDisplay(logs),
      ExerciseSetMetricsStyle.repsOnly ||
      ExerciseSetMetricsStyle.repsAndDuration => _maxRepsInSingleSet(logs),
      ExerciseSetMetricsStyle.durationOnly => _maxDurationSeconds(logs),
    };
  }

  double? _volumeValue(List<SessionSetLog> logs) {
    return switch (_style) {
      ExerciseSetMetricsStyle.repsAndWeight => _totalTonnageDisplay(logs),
      ExerciseSetMetricsStyle.repsOnly ||
      ExerciseSetMetricsStyle.repsAndDuration => _totalReps(logs),
      ExerciseSetMetricsStyle.durationOnly => _totalDurationSeconds(logs),
    };
  }

  double? _maxWeightDisplay(List<SessionSetLog> logs) {
    double? best;
    for (final log in logs) {
      final weight = log.weight;
      if (weight == null) continue;
      final displayValue = _weightInDisplayUnit(weight);
      if (best == null || displayValue > best) best = displayValue;
    }
    return best;
  }

  double? _totalTonnageDisplay(List<SessionSetLog> logs) {
    double total = 0;
    bool any = false;
    for (final log in logs) {
      final weight = log.weight;
      final reps = log.reps;
      if (weight == null || reps == null) continue;
      total += _weightInDisplayUnit(weight) * reps;
      any = true;
    }
    return any ? total : null;
  }

  double? _maxRepsInSingleSet(List<SessionSetLog> logs) {
    int? best;
    for (final log in logs) {
      final reps = log.reps;
      if (reps == null) continue;
      if (best == null || reps > best) best = reps;
    }
    return best?.toDouble();
  }

  double? _totalReps(List<SessionSetLog> logs) {
    int total = 0;
    bool any = false;
    for (final log in logs) {
      final reps = log.reps;
      if (reps == null) continue;
      total += reps;
      any = true;
    }
    return any ? total.toDouble() : null;
  }

  double? _maxDurationSeconds(List<SessionSetLog> logs) {
    int? best;
    for (final log in logs) {
      final seconds = log.duration?.inSeconds;
      if (seconds == null) continue;
      if (best == null || seconds > best) best = seconds;
    }
    return best?.toDouble();
  }

  double? _totalDurationSeconds(List<SessionSetLog> logs) {
    int total = 0;
    bool any = false;
    for (final log in logs) {
      final seconds = log.duration?.inSeconds;
      if (seconds == null) continue;
      total += seconds;
      any = true;
    }
    return any ? total.toDouble() : null;
  }

  double _weightInDisplayUnit(Weight weight) {
    final unit = WeightDisplay.unitForExercise(exercise);
    return unit == WeightUnit.kilograms ? weight.kilograms : weight.pounds;
  }

  String _formatWeight(double value) {
    final unit = WeightDisplay.unitForExercise(exercise);
    final rounded = value.roundToDouble();
    final formatted = (value - rounded).abs() < 0.05
        ? rounded.round().toString()
        : value.toStringAsFixed(1);
    return '$formatted${unit.label}';
  }

  String _formatSeconds(double value) {
    final totalSeconds = value.round();
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (seconds == 0) return '${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}
