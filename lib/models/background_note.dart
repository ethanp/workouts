import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_note.freezed.dart';
part 'background_note.g.dart';

enum NoteCategory {
  injuryHistory,
  preference,
  equipment,
  constraint,
  avoid,
  medical,
  philosophy,
}

enum NoteSource { user, llmSuggested, imported }

@freezed
abstract class BackgroundNote with _$BackgroundNote {
  const factory BackgroundNote({
    required String id,
    required String content,
    required NoteCategory category,
    String? goalId,
    @Default(true) bool isActive,
    @Default(NoteSource.user) NoteSource source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BackgroundNote;

  factory BackgroundNote.fromJson(Map<String, dynamic> json) =>
      _$BackgroundNoteFromJson(json);
}

extension NoteCategoryX on NoteCategory {
  String get displayName => switch (this) {
    NoteCategory.injuryHistory => 'Injury History',
    NoteCategory.preference => 'Preference',
    NoteCategory.equipment => 'Equipment',
    NoteCategory.constraint => 'Constraint',
    NoteCategory.avoid => 'Avoid',
    NoteCategory.medical => 'Medical',
    NoteCategory.philosophy => 'Philosophy',
  };

  String get icon => switch (this) {
    NoteCategory.injuryHistory => '🩹',
    NoteCategory.preference => '💜',
    NoteCategory.equipment => '🏋️',
    NoteCategory.constraint => '⏱️',
    NoteCategory.avoid => '⚠️',
    NoteCategory.medical => '🏥',
    NoteCategory.philosophy => '📚',
  };
}
