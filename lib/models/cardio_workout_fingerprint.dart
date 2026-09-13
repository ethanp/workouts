class const CardioWorkoutFingerprint({
  required final String externalWorkoutId,
  required final DateTime startedAt,
  required final DateTime endedAt,
  required final int durationSeconds,
}) {
  factory fromRow(Map<String, dynamic> workoutRow) {
    return CardioWorkoutFingerprint(
      externalWorkoutId: workoutRow['external_workout_id'] as String,
      startedAt: DateTime.parse(workoutRow['started_at'] as String),
      endedAt: DateTime.parse(workoutRow['ended_at'] as String),
      durationSeconds: (workoutRow['duration_seconds'] as num?)?.round() ?? 0,
    );
  }

  factory fromHealthKitHeader(Map<String, dynamic> header) {
    return CardioWorkoutFingerprint(
      externalWorkoutId: header['externalWorkoutId'] as String,
      startedAt: DateTime.parse(header['startDate'] as String),
      endedAt: DateTime.parse(header['endDate'] as String),
      durationSeconds: (header['durationSeconds'] as num?)?.round() ?? 0,
    );
  }

  String get normalizedExternalId => externalWorkoutId.toLowerCase();

  Map<String, Object> get asHealthKitSkipArgument => {
    'externalWorkoutId': externalWorkoutId,
    'startDate': startedAt.toUtc().toIso8601String(),
    'endDate': endedAt.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  bool matches(CardioWorkoutFingerprint other) {
    if (normalizedExternalId != other.normalizedExternalId) return false;
    if (durationSeconds != other.durationSeconds) return false;
    return _sameSecond(startedAt, other.startedAt) &&
        _sameSecond(endedAt, other.endedAt);
  }

  static bool _sameSecond(DateTime left, DateTime right) =>
      left.toUtc().millisecondsSinceEpoch ~/ 1000 ==
      right.toUtc().millisecondsSinceEpoch ~/ 1000;
}

class const CardioWorkoutFingerprintIndex({
  required final List<CardioWorkoutFingerprint> fingerprints,
}) {
  factory fromRows(Iterable<Map<String, dynamic>> workoutRows) {
    return CardioWorkoutFingerprintIndex(
      fingerprints: [
        for (final workoutRow in workoutRows)
          if ((workoutRow['external_workout_id'] as String?)?.isNotEmpty ==
              true)
            CardioWorkoutFingerprint.fromRow(workoutRow),
      ],
    );
  }

  bool containsUnchanged(CardioWorkoutFingerprint candidate) {
    for (final fingerprint in fingerprints) {
      if (fingerprint.matches(candidate)) return true;
    }
    return false;
  }

  List<Map<String, Object>> get asHealthKitSkipArguments => [
    for (final fingerprint in fingerprints) fingerprint.asHealthKitSkipArgument,
  ];
}
