import 'package:workouts/models/session.dart';

/// One past completed session in which a particular exercise was logged.
///
/// Carries just enough to render the per-exercise history view without
/// hydrating the full Session aggregate. Tapping a session in the UI fetches
/// the full Session by id when needed for drill-down.
class const ExerciseHistoryEntry({
  required final String sessionId,
  required final DateTime completedAt,
  required final String? templateName,

  /// Logs of the queried exercise within this session, ordered by
  /// `block_index` ascending then `set_index` ascending. A multi-block /
  /// multi-round session that contains the exercise more than once will
  /// list every matching set in chronological in-session order.
  required final List<SessionSetLog> sets,
});
