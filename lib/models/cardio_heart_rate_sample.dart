class const CardioHeartRateSample({
  required final String id,
  required final String workoutId,
  required final DateTime timestamp,
  required final int bpm,
  final DateTime? createdAt,
  final DateTime? updatedAt,
}) {
  factory fromRow(Map<String, dynamic> sampleRow) {
    return CardioHeartRateSample(
      id: sampleRow['id'] as String,
      workoutId: sampleRow['workout_id'] as String,
      timestamp: DateTime.parse(sampleRow['timestamp'] as String),
      bpm: (sampleRow['bpm'] as int?) ?? 0,
      createdAt: _asDateTime(sampleRow['created_at']),
      updatedAt: _asDateTime(sampleRow['updated_at']),
    );
  }
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
