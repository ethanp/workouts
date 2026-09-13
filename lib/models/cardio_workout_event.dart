class const CardioWorkoutEvent({
  required final String id,
  required final String workoutId,
  required final String eventType,
  required final DateTime occurredAt,
  final DateTime? endedAt,
}) {
  factory fromRow(Map<String, dynamic> eventRow) {
    return CardioWorkoutEvent(
      id: eventRow['id'] as String,
      workoutId: eventRow['workout_id'] as String,
      eventType: (eventRow['event_type'] as String?) ?? 'other',
      occurredAt: DateTime.parse(eventRow['occurred_at'] as String),
      endedAt: _asDateTime(eventRow['ended_at']),
    );
  }
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
