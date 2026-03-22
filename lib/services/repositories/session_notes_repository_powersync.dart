import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';

part 'session_notes_repository_powersync.g.dart';

@riverpod
SessionNotesRepository sessionNotesRepositoryPowerSync(Ref ref) {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return SessionNotesRepository(powerSyncDatabase);
}

class SessionNotesRepository {
  final PowerSyncDatabase _powerSync;

  SessionNotesRepository(this._powerSync);

  /// Watch all notes for a session.
  Stream<List<SessionNote>> watchNotesForSession(String sessionId) {
    return _powerSync
        .watch(
          'SELECT * FROM session_notes WHERE session_id = ? ORDER BY timestamp ASC',
          parameters: [sessionId],
        )
        .map((noteRows) => noteRows.mapL(SessionNote.fromRow));
  }

  /// Fetch all notes for a session.
  Future<List<SessionNote>> fetchNotesForSession(String sessionId) async {
    final noteRows = await _powerSync.getAll(
      'SELECT * FROM session_notes WHERE session_id = ? ORDER BY timestamp ASC',
      [sessionId],
    );
    return noteRows.mapL(SessionNote.fromRow);
  }

  Future<void> saveNote(SessionNote note) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.upsert(
      'session_notes',
      {
        ...note.toRow(),
        'created_at': now,
        'updated_at': now,
      },
      updateColumns: ['content', 'note_type', 'updated_at'],
    );
  }

  /// Delete a note.
  Future<void> deleteNote(String id) async {
    await _powerSync.execute('DELETE FROM session_notes WHERE id = ?', [id]);
  }
}
