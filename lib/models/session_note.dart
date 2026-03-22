import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_note.freezed.dart';
part 'session_note.g.dart';

enum SessionNoteType { observation, modification, painSignal, breakthrough }

enum SessionNoteSource { user, llmSuggested }

@freezed
abstract class SessionNote with _$SessionNote {
  const SessionNote._();

  const factory SessionNote({
    required String id,
    required String sessionId,
    String? exerciseId,
    String? blockId,
    required String content,
    required SessionNoteType noteType,
    @Default(SessionNoteSource.user) SessionNoteSource source,
    required DateTime timestamp,
  }) = _SessionNote;

  factory SessionNote.fromJson(Map<String, dynamic> json) =>
      _$SessionNoteFromJson(json);

  factory SessionNote.fromRow(Map<String, dynamic> noteRow) {
    return SessionNote(
      id: noteRow['id'] as String,
      sessionId: noteRow['session_id'] as String,
      exerciseId: noteRow['exercise_id'] as String?,
      blockId: noteRow['block_id'] as String?,
      content: noteRow['content'] as String,
      noteType: SessionNoteType.values.firstWhere(
        (sessionNoteType) => sessionNoteType.name == noteRow['note_type'],
        orElse: () => SessionNoteType.observation,
      ),
      source: SessionNoteSource.values.firstWhere(
        (sessionNoteSource) => sessionNoteSource.name == noteRow['source'],
        orElse: () => SessionNoteSource.user,
      ),
      timestamp: DateTime.parse(noteRow['timestamp'] as String),
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'session_id': sessionId,
    'exercise_id': exerciseId,
    'block_id': blockId,
    'content': content,
    'note_type': noteType.name,
    'source': source.name,
    'timestamp': timestamp.toIso8601String(),
  };
}

extension SessionNoteTypeX on SessionNoteType {
  String get displayName => switch (this) {
    SessionNoteType.observation => 'Observation',
    SessionNoteType.modification => 'Modification',
    SessionNoteType.painSignal => 'Pain Signal',
    SessionNoteType.breakthrough => 'Breakthrough',
  };

  String get icon => switch (this) {
    SessionNoteType.observation => '👀',
    SessionNoteType.modification => '🔧',
    SessionNoteType.painSignal => '⚠️',
    SessionNoteType.breakthrough => '🎉',
  };
}
