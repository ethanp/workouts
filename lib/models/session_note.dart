import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_note.freezed.dart';
part 'session_note.g.dart';

enum SessionNoteType { observation, modification, painSignal, breakthrough }

enum SessionNoteSource { user, llmSuggested }

@freezed
abstract class SessionNote with _$SessionNote {
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
