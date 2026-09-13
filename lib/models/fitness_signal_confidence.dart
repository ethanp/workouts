enum FitnessSignalConfidence() {
  high,
  medium,
  low,
  insufficient;

  String get dbKey => name;

  String get displayName => switch (this) {
    high => 'High confidence',
    medium => 'Medium confidence',
    low => 'Low confidence',
    insufficient => 'Not enough data',
  };

  static FitnessSignalConfidence fromDbKey(String? key) => values.firstWhere(
    (confidence) => confidence.name == key,
    orElse: () => insufficient,
  );
}
