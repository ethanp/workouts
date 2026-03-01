class RunHeartRateSample {
  const RunHeartRateSample({
    required this.id,
    required this.runId,
    required this.timestamp,
    required this.bpm,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String runId;
  final DateTime timestamp;
  final int bpm;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
