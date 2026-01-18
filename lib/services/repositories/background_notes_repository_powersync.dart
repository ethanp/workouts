import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/services/powersync_database_provider.dart';

part 'background_notes_repository_powersync.g.dart';

const _uuid = Uuid();

class BackgroundNotesRepositoryPowerSync {
  BackgroundNotesRepositoryPowerSync(this._db);

  final PowerSyncDatabase _db;

  Future<List<BackgroundNote>> fetchNotes() async {
    final rows = await _db.getAll(
      'SELECT * FROM background_notes ORDER BY created_at DESC',
    );
    return rows.map(_noteFromRow).toList();
  }

  Stream<List<BackgroundNote>> watchNotes() {
    return _db
        .watch('SELECT * FROM background_notes ORDER BY created_at DESC')
        .map((rows) => rows.map(_noteFromRow).toList());
  }

  Stream<List<BackgroundNote>> watchActiveNotes() {
    return _db
        .watch(
          'SELECT * FROM background_notes WHERE is_active = 1 ORDER BY created_at DESC',
        )
        .map((rows) => rows.map(_noteFromRow).toList());
  }

  Stream<List<BackgroundNote>> watchNotesForGoal(String goalId) {
    return _db
        .watch(
          'SELECT * FROM background_notes WHERE goal_id = ? ORDER BY created_at DESC',
          parameters: [goalId],
        )
        .map((rows) => rows.map(_noteFromRow).toList());
  }

  Future<void> saveNote(BackgroundNote note) async {
    final now = DateTime.now().toIso8601String();
    final id = note.id.isEmpty ? _uuid.v4() : note.id;

    await _db.execute(
      '''
      INSERT OR REPLACE INTO background_notes (
        id, goal_id, category, content, is_active, source, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        note.goalId,
        _categoryToDb(note.category),
        note.content,
        note.isActive ? 1 : 0,
        note.source.name,
        note.createdAt?.toIso8601String() ?? now,
        now,
      ],
    );
  }

  Future<void> archiveNote(String noteId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE background_notes SET is_active = 0, updated_at = ? WHERE id = ?',
      [now, noteId],
    );
  }

  Future<void> activateNote(String noteId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE background_notes SET is_active = 1, updated_at = ? WHERE id = ?',
      [now, noteId],
    );
  }

  Future<void> deleteNote(String noteId) async {
    await _db.execute('DELETE FROM background_notes WHERE id = ?', [noteId]);
  }

  BackgroundNote _noteFromRow(Map<String, dynamic> row) {
    return BackgroundNote(
      id: row['id'] as String,
      goalId: row['goal_id'] as String?,
      category: _categoryFromDb(row['category'] as String),
      content: row['content'] as String,
      isActive: (row['is_active'] as int?) == 1,
      source: NoteSource.values.firstWhere(
        (s) => s.name == row['source'],
        orElse: () => NoteSource.user,
      ),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }

  String _categoryToDb(NoteCategory category) {
    return switch (category) {
      NoteCategory.injuryHistory => 'injury_history',
      NoteCategory.preference => 'preference',
      NoteCategory.equipment => 'equipment',
      NoteCategory.constraint => 'constraint',
      NoteCategory.avoid => 'avoid',
      NoteCategory.medical => 'medical',
      NoteCategory.philosophy => 'philosophy',
    };
  }

  NoteCategory _categoryFromDb(String dbValue) {
    return switch (dbValue) {
      'injury_history' => NoteCategory.injuryHistory,
      'preference' => NoteCategory.preference,
      'equipment' => NoteCategory.equipment,
      'constraint' => NoteCategory.constraint,
      'avoid' => NoteCategory.avoid,
      'medical' => NoteCategory.medical,
      'philosophy' => NoteCategory.philosophy,
      _ => NoteCategory.preference,
    };
  }
}

@riverpod
BackgroundNotesRepositoryPowerSync backgroundNotesRepositoryPowerSync(Ref ref) {
  final dbAsync = ref.watch(powerSyncDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  return BackgroundNotesRepositoryPowerSync(db);
}
