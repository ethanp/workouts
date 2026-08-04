import 'package:ethan_utils/ethan_utils.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_note.freezed.dart';
part 'background_note.g.dart';

enum NoteCategory {
  injuryHistory(icon: '🩹'),
  preference(icon: '💜'),
  equipment(icon: '🏋️'),
  constraint(icon: '⏱️'),
  avoid(icon: '⚠️'),
  medical(icon: '🏥'),
  philosophy(icon: '📚');

  const NoteCategory({required this.icon});

  final String icon;

  String get dbKey => name.snakeCase;

  static NoteCategory fromDbKey(String dbValue) =>
      NoteCategory.values.firstWhere(
        (noteCategory) => noteCategory.dbKey == dbValue,
        orElse: () => NoteCategory.preference,
      );

  String get displayName => nameAsCapitalizedWords;
}

enum NoteSource { user, llmSuggested, imported }

@freezed
abstract class BackgroundNote with _$BackgroundNote {
  const BackgroundNote._();

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

  factory BackgroundNote.fromRow(Map<String, dynamic> row) {
    return BackgroundNote(
      id: row['id'] as String,
      goalId: row['goal_id'] as String?,
      category: NoteCategory.fromDbKey(row['category'] as String),
      content: row['content'] as String,
      isActive: (row['is_active'] as int? ?? 0) == 1,
      source: NoteSource.values.firstWhere(
        (noteSource) => noteSource.name == row['source'],
        orElse: () => NoteSource.user,
      ),
      createdAt: _asDateTime(row['created_at']),
      updatedAt: _asDateTime(row['updated_at']),
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'goal_id': goalId,
    'category': category.dbKey,
    'content': content,
    'is_active': isActive ? 1 : 0,
    'source': source.name,
  };
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
