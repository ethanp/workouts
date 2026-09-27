abstract final class WorkoutHistory {
  /// First local day of cardio the app keeps. Earlier Apple Health workouts
  /// are low quality and are neither stored nor requested.
  static final firstDay = DateTime(2026, 4, 14);

  static String get firstDayKey {
    final month = firstDay.month.toString().padLeft(2, '0');
    final day = firstDay.day.toString().padLeft(2, '0');
    return '${firstDay.year}-$month-$day';
  }

  static bool startsBeforeFirstDay(DateTime startedAt) {
    final local = startedAt.toLocal();
    final localDay = DateTime(local.year, local.month, local.day);
    return localDay.isBefore(firstDay);
  }
}
