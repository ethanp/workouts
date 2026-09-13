enum DistanceOrigin() {
  machineLinked,
  watchEstimated,
  unknown;

  String get dbKey => name;

  String get displayName => switch (this) {
    machineLinked => 'Machine-linked',
    watchEstimated => 'Watch estimate',
    unknown => 'Unknown source',
  };

  static DistanceOrigin fromDbKey(String? key) => values.firstWhere(
    (origin) => origin.name == key,
    orElse: () => unknown,
  );
}
