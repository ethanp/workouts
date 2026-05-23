import 'package:workouts/models/session.dart';

/// One past completed session in which a particular exercise was logged.
///
/// Carries just enough to render the per-exercise history view without
/// hydrating the full Session aggregate. Tapping a session in the UI fetches
/// the full Session by id when needed for drill-down.
class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.sessionId,
    required this.completedAt,
    required this.templateName,
    required this.sets,
  });

  final String sessionId;
  final DateTime completedAt;
  final String? templateName;

  /// Logs of the queried exercise within this session, ordered by
  /// `block_index` ascending then `set_index` ascending. A multi-block /
  /// multi-round session that contains the exercise more than once will
  /// list every matching set in chronological in-session order.
  final List<SessionSetLog> sets;
}
