import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/services/powersync_database_provider.dart';

part 'session_notes_repository_powersync.g.dart';

@riverpod
SessionNotesRepository sessionNotesRepositoryPowerSync(Ref ref) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  return SessionNotesRepository(db);
}

class SessionNotesRepository {
  final PowerSyncDatabase _db;

  SessionNotesRepository(this._db);

  /// Watch all notes for a session.
  Stream<List<SessionNote>> watchNotesForSession(String sessionId) {
    return _db
        .watch(
          'SELECT * FROM session_notes WHERE session_id = ? ORDER BY timestamp ASC',
          parameters: [sessionId],
        )
        .map((rows) => rows.map(_mapRowToNote).toList());
  }

  /// Fetch all notes for a session.
  Future<List<SessionNote>> fetchNotesForSession(String sessionId) async {
    final rows = await _db.getAll(
      'SELECT * FROM session_notes WHERE session_id = ? ORDER BY timestamp ASC',
      [sessionId],
    );
    return rows.map(_mapRowToNote).toList();
  }

  /// Save a new note or update existing.
  Future<void> saveNote(SessionNote note) async {
    final existing = await _db.getOptional(
      'SELECT id FROM session_notes WHERE id = ?',
      [note.id],
    );
    final now = DateTime.now().toIso8601String();
    if (existing == null) {
      await _db.execute(
        '''
        INSERT INTO session_notes (
          id, session_id, exercise_id, block_id, content, note_type, source, timestamp, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          note.id,
          note.sessionId,
          note.exerciseId,
          note.blockId,
          note.content,
          note.noteType.name,
          note.source.name,
          note.timestamp.toIso8601String(),
          now,
          now,
        ],
      );
    } else {
      await _db.execute(
        '''
        UPDATE session_notes
        SET content = ?, note_type = ?, updated_at = ?
        WHERE id = ?
        ''',
        [note.content, note.noteType.name, now, note.id],
      );
    }
  }

  /// Delete a note.
  Future<void> deleteNote(String id) async {
    await _db.execute('DELETE FROM session_notes WHERE id = ?', [id]);
  }

  SessionNote _mapRowToNote(Map<String, dynamic> row) {
    return SessionNote(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      exerciseId: row['exercise_id'] as String?,
      blockId: row['block_id'] as String?,
      content: row['content'] as String,
      noteType: SessionNoteType.values.firstWhere(
        (e) => e.name == row['note_type'],
        orElse: () => SessionNoteType.observation,
      ),
      source: SessionNoteSource.values.firstWhere(
        (e) => e.name == row['source'],
        orElse: () => SessionNoteSource.user,
      ),
      timestamp: DateTime.parse(row['timestamp'] as String),
    );
  }
}
