class CardioHeartRateSample {
  const CardioHeartRateSample({
    required this.id,
    required this.workoutId,
    required this.timestamp,
    required this.bpm,
    this.createdAt,
    this.updatedAt,
  });

  factory CardioHeartRateSample.fromRow(Map<String, dynamic> sampleRow) {
    return CardioHeartRateSample(
      id: sampleRow['id'] as String,
      workoutId: sampleRow['workout_id'] as String,
      timestamp: DateTime.parse(sampleRow['timestamp'] as String),
      bpm: (sampleRow['bpm'] as int?) ?? 0,
      createdAt: _asDateTime(sampleRow['created_at']),
      updatedAt: _asDateTime(sampleRow['updated_at']),
    );
  }

  final String id;
  final String workoutId;
  final DateTime timestamp;
  final int bpm;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
