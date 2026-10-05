import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/session.dart';

/// Unified list item for cardio workouts and sessions, ordered by started_at.
sealed class ActivityItem() {
  DateTime get startedAt;

  bool matchesListedActivityType(CardioType? activityType) {
    if (activityType == null) return true;
    return switch (this) {
      ActivityCardio(:final workout) => workout.activityType == activityType,
      ActivitySession() => false,
    };
  }
}

final class ActivityCardio(final CardioWorkout workout) extends ActivityItem {
  @override
  DateTime get startedAt => workout.startedAt;
}

final class ActivitySession(final Session session) extends ActivityItem {
  @override
  DateTime get startedAt => session.startedAt;
}
