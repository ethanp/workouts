import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/session.dart';

/// Unified list item for runs and sessions, ordered by started_at.
sealed class ActivityItem {
  DateTime get startedAt;
}

final class ActivityRun extends ActivityItem {
  ActivityRun(this.run);

  final FitnessRun run;

  @override
  DateTime get startedAt => run.startedAt;
}

final class ActivitySession extends ActivityItem {
  ActivitySession(this.session);

  final Session session;

  @override
  DateTime get startedAt => session.startedAt;
}
