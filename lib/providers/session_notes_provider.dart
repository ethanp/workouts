import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/services/repositories/session_notes_repository_powersync.dart';

part 'session_notes_provider.g.dart';

const _uuid = Uuid();

@riverpod
Stream<List<SessionNote>> sessionNotesStream(Ref ref, String sessionId) {
  final repo = ref.watch(sessionNotesRepositoryPowerSyncProvider);
  return repo.watchNotesForSession(sessionId);
}

@riverpod
class SessionNotesController extends _$SessionNotesController {
  @override
  void build() {}

  Future<void> addNote({
    required String sessionId,
    required String content,
    required SessionNoteType noteType,
    String? exerciseId,
    String? blockId,
  }) async {
    final repo = ref.read(sessionNotesRepositoryPowerSyncProvider);
    final note = SessionNote(
      id: _uuid.v4(),
      sessionId: sessionId,
      exerciseId: exerciseId,
      blockId: blockId,
      content: content,
      noteType: noteType,
      source: SessionNoteSource.user,
      timestamp: DateTime.now(),
    );
    await repo.saveNote(note);
  }

  Future<void> updateNote(SessionNote note, String newContent) async {
    final repo = ref.read(sessionNotesRepositoryPowerSyncProvider);
    await repo.saveNote(note.copyWith(content: newContent));
  }

  Future<void> deleteNote(String id) async {
    final repo = ref.read(sessionNotesRepositoryPowerSyncProvider);
    await repo.deleteNote(id);
  }
}
