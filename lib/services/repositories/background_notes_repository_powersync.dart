import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';

part 'background_notes_repository_powersync.g.dart';

const _uuid = Uuid();

class BackgroundNotesRepositoryPowerSync {
  BackgroundNotesRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<BackgroundNote>> fetchNotes() async {
    final noteRows = await _powerSync.getAll(
      'SELECT * FROM background_notes ORDER BY created_at DESC',
    );
    return noteRows.mapL(BackgroundNote.fromRow);
  }

  Stream<List<BackgroundNote>> watchNotes() {
    return _powerSync
        .watch('SELECT * FROM background_notes ORDER BY created_at DESC')
        .map((noteRows) => noteRows.mapL(BackgroundNote.fromRow));
  }

  Stream<List<BackgroundNote>> watchActiveNotes() {
    return _powerSync
        .watch(
          'SELECT * FROM background_notes WHERE is_active = 1 ORDER BY created_at DESC',
        )
        .map((noteRows) => noteRows.mapL(BackgroundNote.fromRow));
  }

  Stream<List<BackgroundNote>> watchNotesForGoal(String goalId) {
    return _powerSync
        .watch(
          'SELECT * FROM background_notes WHERE goal_id = ? ORDER BY created_at DESC',
          parameters: [goalId],
        )
        .map((noteRows) => noteRows.mapL(BackgroundNote.fromRow));
  }

  Future<void> saveNote(BackgroundNote note) async {
    final now = DateTime.now().toIso8601String();
    final resolvedNote = note.id.isEmpty ? note.copyWith(id: _uuid.v4()) : note;

    await _powerSync.upsert('background_notes', {
      ...resolvedNote.toRow(),
      'created_at': note.createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    });
  }

  Future<void> archiveNote(String noteId) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      'UPDATE background_notes SET is_active = 0, updated_at = ? WHERE id = ?',
      [now, noteId],
    );
  }

  Future<void> activateNote(String noteId) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      'UPDATE background_notes SET is_active = 1, updated_at = ? WHERE id = ?',
      [now, noteId],
    );
  }

  Future<void> deleteNote(String noteId) async {
    await _powerSync.execute('DELETE FROM background_notes WHERE id = ?', [
      noteId,
    ]);
  }
}

@riverpod
BackgroundNotesRepositoryPowerSync backgroundNotesRepositoryPowerSync(Ref ref) {
  final powerSyncDatabaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = powerSyncDatabaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return BackgroundNotesRepositoryPowerSync(powerSyncDatabase);
}
