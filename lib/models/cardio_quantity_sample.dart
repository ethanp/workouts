class const CardioQuantitySample({
  required final String id,
  required final String workoutId,
  required final DateTime startedAt,
  required final DateTime endedAt,
  required final double value,
}) {
  factory fromRow(Map<String, dynamic> sampleRow) {
    return CardioQuantitySample(
      id: sampleRow['id'] as String,
      workoutId: sampleRow['workout_id'] as String,
      startedAt: DateTime.parse(sampleRow['started_at'] as String),
      endedAt: DateTime.parse(sampleRow['ended_at'] as String),
      value: _asDouble(sampleRow['value']) ?? 0,
    );
  }

  Duration get interval => endedAt.difference(startedAt);
}

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}
