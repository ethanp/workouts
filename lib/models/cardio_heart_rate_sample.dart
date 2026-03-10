class CardioHeartRateSample {
  const CardioHeartRateSample({
    required this.id,
    required this.workoutId,
    required this.timestamp,
    required this.bpm,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workoutId;
  final DateTime timestamp;
  final int bpm;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
