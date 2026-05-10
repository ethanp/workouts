enum ExerciseSetMetricsStyle {
  repsOnly,
  repsAndWeight,
  durationOnly,
  repsAndDuration,
}

class ExerciseSetMetrics {
  const ExerciseSetMetrics(this.style);

  final ExerciseSetMetricsStyle style;

  bool get tracksReps {
    return style == ExerciseSetMetricsStyle.repsOnly ||
        style == ExerciseSetMetricsStyle.repsAndWeight ||
        style == ExerciseSetMetricsStyle.repsAndDuration;
  }

  bool get supportsAddedWeight =>
      style == ExerciseSetMetricsStyle.repsAndWeight;

  bool get tracksDuration {
    return style == ExerciseSetMetricsStyle.durationOnly ||
        style == ExerciseSetMetricsStyle.repsAndDuration;
  }

  String get label => switch (style) {
    ExerciseSetMetricsStyle.repsOnly => 'reps',
    ExerciseSetMetricsStyle.repsAndWeight => 'reps + weight',
    ExerciseSetMetricsStyle.durationOnly => 'time',
    ExerciseSetMetricsStyle.repsAndDuration => 'reps + time',
  };
}
