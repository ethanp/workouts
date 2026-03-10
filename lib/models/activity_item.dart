import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/session.dart';

/// Unified list item for cardio workouts and sessions, ordered by started_at.
sealed class ActivityItem {
  DateTime get startedAt;
}

final class ActivityCardio extends ActivityItem {
  ActivityCardio(this.workout);

  final CardioWorkout workout;

  @override
  DateTime get startedAt => workout.startedAt;
}

final class ActivitySession extends ActivityItem {
  ActivitySession(this.session);

  final Session session;

  @override
  DateTime get startedAt => session.startedAt;
}
