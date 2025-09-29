class HealthExportSummary {
  const HealthExportSummary({
    required this.exportedWorkoutUUIDs,
    this.lastDeletionAt,
    this.lastError,
  });

  final List<String> exportedWorkoutUUIDs;
  final DateTime? lastDeletionAt;
  final String? lastError;

  int get remainingCount => exportedWorkoutUUIDs.length;

  HealthExportSummary copyWith({
    List<String>? exportedWorkoutUUIDs,
    DateTime? lastDeletionAt,
    String? lastError,
    bool clearError = false,
  }) {
    return HealthExportSummary(
      exportedWorkoutUUIDs: exportedWorkoutUUIDs ?? this.exportedWorkoutUUIDs,
      lastDeletionAt: lastDeletionAt ?? this.lastDeletionAt,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}
